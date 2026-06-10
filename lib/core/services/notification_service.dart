import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.instance.initialize();
  await NotificationService.instance.showRemoteMessage(message);
}

/// Data minimal sebuah event untuk menjadwalkan reminder.
class ReminderEvent {
  final int eventId;
  final String title;
  final DateTime? start;
  const ReminderEvent({required this.eventId, required this.title, this.start});
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Channels ──
  static const _pushChannel = AndroidNotificationChannel(
    'evoria_high_importance',
    'Evoria Notifications',
    description: 'Notifikasi pembayaran dan info event Evoria',
    importance: Importance.high,
  );

  static const _reminderChannel = AndroidNotificationChannel(
    'evoria_event_reminders',
    'Pengingat Event',
    description: 'Pengingat untuk event yang tiketnya sudah kamu beli',
    importance: Importance.high,
  );

  /// Berapa lama sebelum event mulai reminder dikirim. Urutan = slot id.
  static const _reminderOffsets = <Duration>[
    Duration(hours: 24),
    Duration(hours: 3),
  ];

  /// Inisialisasi notifikasi lokal (channel + timezone + izin).
  /// Tidak butuh Firebase — aman dipanggil walau FCM gagal/diabaikan.
  Future<void> initialize() async {
    if (_initialized) return;
    await _initTimezone();
    await _setupLocalNotifications();
    await _requestPermission();
    _initialized = true;
  }

  /// Pasang listener pesan FCM foreground. Panggil hanya jika Firebase aktif.
  void attachFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen(showRemoteMessage);
  }

  Future<void> _initTimezone() async {
    tz.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Gagal deteksi timezone device → fallback ke WIB.
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } catch (_) {
        /* biarkan default (UTC) */
      }
    }
  }

  Future<void> _requestPermission() async {
    if (Platform.isIOS) {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } else {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings(
      '@drawable/ic_stat_evoria',
    );
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(initSettings);

    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_pushChannel);
    await android?.createNotificationChannel(_reminderChannel);
  }

  // ── Push dari FCM (dipakai kalau nanti ada backend sender) ──
  Future<void> showRemoteMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      _details(_pushChannel),
    );
  }

  // ── Notifikasi saat order dibuat (instan, setiap pembelian) ──
  /// Dipicu tepat saat order berhasil dibuat — tidak menunggu pembayaran,
  /// jadi setiap pembelian selalu memunculkan notifikasi. [orderKey] (nomor
  /// order) membuat tiap order punya notifikasi terpisah (tidak saling timpa).
  Future<void> showOrderPlaced({
    required String eventTitle,
    required String orderKey,
    required bool isFree,
  }) async {
    final (title, body) = isFree
        ? (
            'Tiket berhasil dipesan 🎉',
            'Tiket untuk "$eventTitle" sudah masuk. Lihat di menu Tiket.',
          )
        : (
            'Pesanan berhasil dibuat 🎟️',
            'Selesaikan pembayaran untuk "$eventTitle" agar tiket aktif.',
          );
    await _localNotifications.show(
      _orderPlacedId(orderKey),
      title,
      body,
      _details(_reminderChannel),
    );
  }

  // ── Notifikasi saat pembayaran lunas (instan) ──
  Future<void> showPaymentSuccess({
    required String eventTitle,
    required String orderKey,
  }) async {
    await _localNotifications.show(
      _paymentSuccessId(orderKey),
      'Pembayaran berhasil 🎉',
      'Tiket untuk "$eventTitle" sudah aktif. Lihat di menu Tiket.',
      _details(_reminderChannel),
    );
  }

  // ── Reminder terjadwal (24 jam & 3 jam sebelum event) ──
  /// Jadwalkan reminder untuk satu event. Slot yang waktunya sudah lewat dilewati.
  Future<void> scheduleEventReminders(ReminderEvent event) async {
    final start = event.start;
    if (start == null) return;
    final now = DateTime.now();

    for (var slot = 0; slot < _reminderOffsets.length; slot++) {
      final fireAt = start.subtract(_reminderOffsets[slot]);
      if (!fireAt.isAfter(now)) continue; // sudah lewat → skip

      final (title, body) = _reminderCopy(_reminderOffsets[slot], event.title);
      await _localNotifications.zonedSchedule(
        _reminderId(event.eventId, slot),
        title,
        body,
        tz.TZDateTime.from(fireAt, tz.local),
        _details(_reminderChannel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Batalkan semua reminder terjadwal lalu jadwalkan ulang dari [events].
  /// Dipakai saat app dibuka untuk rekonsiliasi (tahan restart device).
  Future<void> syncEventReminders(List<ReminderEvent> events) async {
    final pending = await _localNotifications.pendingNotificationRequests();
    for (final p in pending) {
      await _localNotifications.cancel(p.id);
    }
    for (final e in events) {
      await scheduleEventReminders(e);
    }
  }

  // ── Helpers ──
  NotificationDetails _details(AndroidNotificationChannel channel) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_stat_evoria',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: const DarwinNotificationDetails(),
      );

  (String, String) _reminderCopy(Duration offset, String title) {
    if (offset.inHours >= 24) {
      return (
        'Event besok 🎟️',
        '"$title" dimulai besok. Jangan sampai terlewat!',
      );
    }
    return (
      'Sebentar lagi mulai ⏰',
      '"$title" dimulai dalam 3 jam. Siapkan e-tiketmu.',
    );
  }

  // ID notifikasi Android harus muat di 32-bit → batasi rentang eventId.
  int _reminderId(int eventId, int slot) => (eventId % 1000000) * 10 + slot;

  // Namespace ID terpisah agar notif "order dibuat" & "pembayaran berhasil"
  // pada order yang sama tidak saling menimpa.
  int _orderPlacedId(String orderKey) =>
      700000000 + (orderKey.hashCode.abs() % 50000000);

  int _paymentSuccessId(String orderKey) =>
      760000000 + (orderKey.hashCode.abs() % 50000000);

  Future<String?> getToken() => _messaging.getToken();
}
