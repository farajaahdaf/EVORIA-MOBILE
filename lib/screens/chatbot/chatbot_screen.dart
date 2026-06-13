import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../providers/location_provider.dart';
import '../../providers/orders_provider.dart';
import '../../repositories/chatbot_repository.dart';
import '../../widgets/event_card.dart';
import '../../widgets/evoria_app_bar.dart';

final _chatLoadingProvider = StateProvider<bool>((ref) => false);

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Kata kunci yang menandakan user butuh hasil berbasis lokasi saat ini.
  static const _locationKeywords = [
    'terdekat',
    'paling dekat',
    'dekat sini',
    'dekat saya',
    'di sekitar',
    'sekitar saya',
    'sekitar sini',
    'lokasi saya',
    'lokasiku',
    'dari lokasi',
    'dari sini',
    'jarak',
    'nearby',
    'near me',
    'nearest',
    'closest',
  ];

  bool _isLocationQuery(String text) {
    final t = text.toLowerCase();
    return _locationKeywords.any(t.contains);
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final notifier = ref.read(chatbotMessagesProvider.notifier);
    notifier.addMessage(ChatMessage(text: text, isUser: true));
    _ctrl.clear();
    ref.read(_chatLoadingProvider.notifier).state = true;
    _scrollToBottom();

    try {
      // Pertanyaan berbau lokasi → coba ambil posisi sekarang agar backend bisa
      // mengurutkan event dari yang terdekat & melampirkan jaraknya.
      double? lat;
      double? lng;
      if (_isLocationQuery(text)) {
        final pos = await _resolveLocation();
        if (pos != null) {
          lat = pos.latitude;
          lng = pos.longitude;
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Lokasi tidak tersedia. Aktifkan GPS/izin lokasi untuk hasil terdekat.'),
            ),
          );
        }
      }

      final result = await ref
          .read(chatbotRepositoryProvider)
          .sendMessage(text, lat: lat, lng: lng);
      notifier.addMessage(ChatMessage(
        text: result.text,
        isUser: false,
        events: result.events,
      ));
    } catch (e) {
      notifier.addMessage(
        ChatMessage(text: 'Maaf, terjadi kesalahan. Coba lagi.', isUser: false),
      );
    } finally {
      ref.read(_chatLoadingProvider.notifier).state = false;
      _scrollToBottom();
    }
  }

  /// Ambil lokasi untuk query "terdekat" dengan batas waktu, supaya GPS yang
  /// lama merespons (umum di emulator) tidak menggantung chat selamanya.
  /// Kalau gagal/timeout, pakai posisi terakhir yang diketahui (dibagi dengan
  /// Beranda lewat [userPositionProvider]).
  Future<Position?> _resolveLocation() async {
    final cached = ref.read(userPositionProvider);
    try {
      final result = await LocationService.getCurrentPosition()
          .timeout(const Duration(seconds: 12));
      if (result.isSuccess) {
        // Bagikan posisi terbaru agar Beranda ikut konsisten.
        ref.read(userPositionProvider.notifier).state = result.position;
        return result.position;
      }
    } catch (_) {
      // timeout / error → jatuh ke posisi cache di bawah.
    }
    return cached;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatbotMessagesProvider);
    final loading = ref.watch(_chatLoadingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: EvoriaAppBar(
        title: 'Evoria AI',
        actions: [
          if (messages.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.textSecondary,
              ),
              onPressed: () {
                ref.read(chatbotMessagesProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _buildWelcome()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + (loading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (loading && i == messages.length) {
                        return const _TypingIndicator();
                      }
                      return _ChatBubble(message: messages[i]);
                    },
                  ),
          ),
          _buildInput(loading),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppGradients.brand,
              shape: BoxShape.circle,
              boxShadow: AppShadows.glow(AppColors.primary, opacity: 0.35),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Evoria AI Assistant',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tanyakan apa saja tentang event yang kamu cari!',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const Text(
            'Contoh pertanyaan:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ..._suggestions.map(
            (s) => GestureDetector(
              onTap: () {
                _ctrl.text = s;
                _send();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.rMd,
                  boxShadow: AppShadows.soft,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        gradient: AppGradients.brand,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_outward_rounded,
                          size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _suggestions = [
    'Event terdekat dari lokasi saya',
    'Ada konser di Jakarta bulan ini?',
    'Event murah akhir pekan ini?',
    'Cari workshop teknologi terdekat',
    'Event gratis di Bandung?',
  ];

  Widget _buildInput(bool loading) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Tanya tentang event...',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: loading ? null : _send,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: loading ? null : AppGradients.brand,
                color: loading ? AppColors.borderStrong : null,
                shape: BoxShape.circle,
                boxShadow: loading
                    ? null
                    : AppShadows.glow(AppColors.primary, opacity: 0.3),
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: message.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!message.isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    gradient: AppGradients.brand,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      size: 17, color: Colors.white),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: message.isUser ? AppGradients.brand : null,
                    color: message.isUser ? null : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: message.isUser
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: message.isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                    boxShadow: AppShadows.soft,
                  ),
                  child: message.isUser
                      ? Text(
                          message.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        )
                      : MarkdownBody(
                          data: message.text,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              height: 1.5,
                            ),
                            a: const TextStyle(
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                ),
              ),
              if (message.isUser) const SizedBox(width: 4),
            ],
          ),
          // Event cards below AI bubble
          if (!message.isUser && message.events.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: _EventCards(events: message.events),
            ),
          ],
        ],
      ),
    );
  }
}

class _EventCards extends StatelessWidget {
  final List<ChatEventCard> events;
  const _EventCards({required this.events});

  @override
  Widget build(BuildContext context) {
    final hasDistance = events.any((e) => e.distanceKm != null);
    return SizedBox(
      height: hasDistance ? 152 : 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: events.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _EventChip(event: events[i]),
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  final ChatEventCard event;
  const _EventChip({required this.event});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/events/${event.id}'),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            SizedBox(
              height: 62,
              width: double.infinity,
              child: event.bannerUrl != null
                  ? CachedNetworkImage(
                      imageUrl: event.bannerUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _placeholderBanner(),
                    )
                  : _placeholderBanner(),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (event.date != null)
                    Text(
                      event.date!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (event.distanceKm != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me_rounded,
                            size: 11, color: AppColors.primary),
                        const SizedBox(width: 3),
                        Text(
                          '${EventCard.formatDistance(event.distanceKm!)} dari lokasimu',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (event.lowestPrice != null)
                        Flexible(
                          child: Text(
                            event.lowestPrice == 0
                                ? 'Gratis'
                                : formatRupiah(event.lowestPrice!),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: AppColors.textLight,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderBanner() => Container(
        color: AppColors.primaryLight,
        child: const Center(
          child: Icon(Icons.event, color: AppColors.primary, size: 24),
        ),
      );
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  int _msgIndex = 0;
  static const _messages = [
    '🤖 Tunggu ya, kita lagi siapkan jawabannya...',
    '📅 Mengecek event yang tersedia...',
    '✨ Hampir selesai, sebentar ya!',
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    // Ganti pesan setiap 2.5 detik
    _scheduleNext();
  }

  void _scheduleNext() {
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _fadeCtrl.reverse().then((_) {
        if (!mounted) return;
        setState(() => _msgIndex = (_msgIndex + 1) % _messages.length);
        _fadeCtrl.forward();
        _scheduleNext();
      });
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              gradient: AppGradients.brand,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 17, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: const BoxConstraints(maxWidth: 260),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Text(
                _messages[_msgIndex],
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
