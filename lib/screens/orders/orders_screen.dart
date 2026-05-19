import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../models/order_model.dart';
import '../../providers/orders_provider.dart';
import '../../widgets/evoria_app_bar.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: EvoriaAppBar(
        title: 'Tiket Saya',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: () => ref.invalidate(ordersProvider),
          ),
        ],
      ),
      body: ordersAsync.when(
        data: (orders) => orders.isEmpty
            ? const _EmptyOrders()
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(ordersProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _OrderCard(order: orders[i]),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: AppColors.textLight),
              const SizedBox(height: 12),
              Text(e.toString(),
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(ordersProvider),
                style: OutlinedButton.styleFrom(minimumSize: const Size(120, 40)),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.confirmation_number_outlined,
              size: 64, color: AppColors.textLight),
          const SizedBox(height: 16),
          const Text(
            'Belum ada tiket',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Yuk, cari event seru dan beli tiketnya!',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(160, 44)),
            child: const Text('Jelajahi Event'),
          ),
        ],
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
    final eventTitle = event?.title ?? firstItem?.ticket?.name ?? 'Event';

    return GestureDetector(
      onTap: () => context.push('/orders/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _statusBadge(order.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              eventTitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (event?.startTime != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    formatDateTime(event!.startTime),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatDate(order.createdAt),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  order.totalAmount == 0
                      ? 'Gratis'
                      : formatRupiah(order.totalAmount),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final (color, bg) = switch (status) {
      'paid' => (AppColors.success, AppColors.success.withOpacity(0.1)),
      'pending' => (AppColors.warning, AppColors.warning.withOpacity(0.1)),
      'cancelled' || 'failed' => (AppColors.error, AppColors.error.withOpacity(0.1)),
      _ => (AppColors.textSecondary, AppColors.border),
    };
    final label = switch (status) {
      'paid' => 'Berhasil',
      'pending' => 'Pending',
      'cancelled' => 'Dibatalkan',
      'failed' => 'Gagal',
      _ => status,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
