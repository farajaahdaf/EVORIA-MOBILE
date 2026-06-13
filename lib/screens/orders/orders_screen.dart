import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../widgets/evoria_app_bar.dart';
import '../../widgets/guest_prompt.dart';

/// Arah pengurutan berdasarkan tanggal pemesanan (order date).
enum _OrderSort { newest, oldest }

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  _OrderSort _sort = _OrderSort.newest;

  /// Kunci bulan event yang dipilih (year*100 + month). null = semua bulan.
  int? _monthKey;

  /// Tanggal mulai event dari sebuah order (acuan filter bulan).
  DateTime? _eventStartOf(OrderModel order) {
    if (order.orderItems.isEmpty) return null;
    return order.orderItems.first.ticket?.event?.startTime;
  }

  /// Tanggal acuan pengurutan (tanggal order; fallback id agar stabil).
  DateTime _orderDateOf(OrderModel order) =>
      order.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  int? _monthKeyOf(DateTime? dt) => dt == null ? null : dt.year * 100 + dt.month;

  /// Daftar bulan event yang tersedia dari semua order, urut menaik.
  List<int> _availableMonths(List<OrderModel> orders) {
    final keys = <int>{};
    for (final o in orders) {
      final k = _monthKeyOf(_eventStartOf(o));
      if (k != null) keys.add(k);
    }
    final list = keys.toList()..sort();
    return list;
  }

  List<OrderModel> _applySortFilter(List<OrderModel> orders) {
    var list = orders;
    if (_monthKey != null) {
      list = list
          .where((o) => _monthKeyOf(_eventStartOf(o)) == _monthKey)
          .toList();
    } else {
      list = List.of(list);
    }
    list.sort((a, b) {
      final cmp = _orderDateOf(a).compareTo(_orderDateOf(b));
      return _sort == _OrderSort.newest ? -cmp : cmp;
    });
    return list;
  }

  String _monthLabel(int key) {
    final dt = DateTime(key ~/ 100, key % 100);
    return DateFormat('MMM yyyy', 'id_ID').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    // Guest (belum login) → minta masuk dulu, jangan panggil API yang 401.
    if (auth.status != AuthStatus.authenticated) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: const EvoriaAppBar(title: 'Tiket Saya'),
        body: const GuestPrompt(
          icon: Icons.confirmation_number_outlined,
          title: 'Lihat Tiket Kamu',
          message: 'Masuk untuk melihat pesanan dan e-tiket yang sudah kamu beli.',
          returnTo: '/orders',
        ),
      );
    }

    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: EvoriaAppBar(
        title: 'Tiket Saya',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () => ref.invalidate(ordersProvider),
          ),
        ],
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) return const _EmptyOrders();
          final months = _availableMonths(orders);
          final visible = _applySortFilter(orders);
          return Column(
            children: [
              _buildControls(months),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(ordersProvider),
                  child: visible.isEmpty
                      ? _buildNoMatch()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 14),
                          itemBuilder: (_, i) => _OrderCard(order: visible[i]),
                        ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textLight),
              const SizedBox(height: 12),
              Text(e.toString(),
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(ordersProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba lagi'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(140, 42)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(List<int> months) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Urutkan berdasarkan tanggal pemesanan ──────────────────────
          Row(
            children: [
              const Icon(Icons.sort_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Text(
                'Urutkan',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary),
              ),
              const Spacer(),
              _sortPill('Terbaru', _OrderSort.newest),
              const SizedBox(width: 8),
              _sortPill('Terlama', _OrderSort.oldest),
            ],
          ),
          if (months.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.event_rounded, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Text(
                  'Bulan event',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _monthChip('Semua', null),
                  ...months.map((k) => _monthChip(_monthLabel(k), k)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sortPill(String label, _OrderSort value) {
    final selected = _sort == value;
    return GestureDetector(
      onTap: () => setState(() => _sort = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected ? AppGradients.brand : null,
          color: selected ? null : AppColors.surface,
          borderRadius: AppRadius.rSm,
          border: Border.all(
              color: selected ? Colors.transparent : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _monthChip(String label, int? key) {
    final selected = _monthKey == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _monthKey = key),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: selected ? AppGradients.brand : null,
            color: selected ? null : AppColors.surface,
            borderRadius: AppRadius.rSm,
            border: Border.all(
                color: selected ? Colors.transparent : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoMatch() {
    return ListView(
      // Tetap scrollable agar RefreshIndicator bisa dipakai.
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.filter_alt_off_rounded,
                    size: 44, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tidak ada tiket di bulan ini',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Coba pilih bulan lain atau lihat semua.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Center(
                child: OutlinedButton(
                  onPressed: () => setState(() => _monthKey = null),
                  child: const Text('Tampilkan semua'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.confirmation_number_outlined,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum ada tiket',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Yuk, cari event seru dan pesan tiketnya!',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Jelajahi Event'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(180, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final firstItem = order.orderItems.isNotEmpty ? order.orderItems.first : null;
    final event = firstItem?.ticket?.event;
    final bannerUrl = event?.bannerUrl;
    final ticketName = firstItem?.ticket?.name ?? '';
    final qty = firstItem?.quantity ?? 0;

    final (statusColor, statusBg, statusIcon) = _statusStyle(order.status);

    return GestureDetector(
      onTap: () => context.push('/orders/${order.id}'),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.rLg,
          boxShadow: AppShadows.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Banner ─────────────────────────────────────────────────
            Stack(
              children: [
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: bannerUrl != null && bannerUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: bannerUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => _placeholderBanner(),
                        )
                      : _placeholderBanner(),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                // Status badge top-right
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          order.statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Event title bottom-left overlay
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Text(
                    event?.title ?? ticketName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.3,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                    ),
                  ),
                ),
              ],
            ),

            // ── Body ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date + location row
                  if (event?.startTime != null)
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 5),
                        Text(
                          formatDateTime(event!.startTime!),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  if (event?.locationName != null && event!.locationName!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            event.locationName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Ticket info + price row
                  Row(
                    children: [
                      // Ticket type chip
                      if (ticketName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$ticketName${qty > 1 ? ' ×$qty' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        order.totalAmount == 0
                            ? 'Gratis'
                            : formatRupiah(order.totalAmount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),

                  // Pending: pay button
                  if (order.isPending) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => context.push('/orders/${order.id}'),
                      child: Container(
                        height: 44,
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AppGradients.brand,
                          borderRadius: AppRadius.rMd,
                          boxShadow:
                              AppShadows.glow(AppColors.primary, opacity: 0.28),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.payment_rounded,
                                size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Selesaikan Pembayaran',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
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
        child: Center(
          child: Icon(
            Icons.event_rounded,
            size: 40,
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
        ),
      );

  (Color, Color, IconData) _statusStyle(String status) => switch (status) {
        'paid' => (
          AppColors.success,
          AppColors.success.withValues(alpha: 0.15),
          Icons.check_circle_rounded
        ),
        'pending' => (
          AppColors.warning,
          AppColors.warning.withValues(alpha: 0.15),
          Icons.schedule_rounded
        ),
        'cancelled' || 'failed' => (
          AppColors.error,
          AppColors.error.withValues(alpha: 0.15),
          Icons.cancel_rounded
        ),
        _ => (
          AppColors.textSecondary,
          AppColors.border,
          Icons.help_outline_rounded
        ),
      };
}
