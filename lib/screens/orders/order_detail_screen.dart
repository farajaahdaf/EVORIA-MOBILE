import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../models/order_model.dart';
import '../../models/order_item_model.dart';
import '../../providers/orders_provider.dart';
import '../../repositories/order_repository.dart';
import '../../widgets/evoria_app_bar.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _syncing = false;
  bool _cancelling = false;

  Future<void> _syncStatus(OrderModel order) async {
    setState(() => _syncing = true);
    try {
      await ref.read(orderRepositoryProvider).syncOrderStatus(order.id);
      ref.invalidate(orderDetailProvider(order.id));
      ref.invalidate(ordersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status berhasil diperbarui')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _cancelOrder(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan Order?'),
        content: Text(
          'Order ${order.orderNumber} akan dibatalkan dan stok tiket dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await ref.read(orderRepositoryProvider).cancelOrder(order.id);
      ref.invalidate(orderDetailProvider(order.id));
      ref.invalidate(ordersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order berhasil dibatalkan'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: EvoriaAppBar(
        title: 'Detail Order',
        actions: [
          orderAsync.whenData((o) => o).value?.isPending == true
              ? IconButton(
                  icon: _syncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: _syncing
                      ? null
                      : () => orderAsync.whenData(_syncStatus),
                )
              : const SizedBox.shrink(),
        ],
      ),
      body: orderAsync.when(
        data: (order) => _buildContent(order),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }

  Widget _buildContent(OrderModel order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildOrderInfo(order),
          const SizedBox(height: 12),
          ...order.orderItems.map((item) => _buildTicketItem(item)),
          const SizedBox(height: 12),
          _buildTotalSection(order),
          if (order.isPending) ...[
            const SizedBox(height: 16),
            _buildCancelButton(order),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOrderInfo(OrderModel order) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('No. Order',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              _statusBadge(order.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            order.orderNumber,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tanggal',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(
                formatDateTime(order.createdAt),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (order.paymentMethod != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Metode Bayar',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text(
                  order.paymentMethod!.toUpperCase(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTicketItem(OrderItemModel item) {
    final event = item.ticket?.event;
    final hasETickets = item.eTickets.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event != null) ...[
            Text(
              event.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.ticket?.name ?? '-'}  ×${item.quantity}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              Text(
                formatRupiah(item.subtotal),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (hasETickets) ...[
            const SizedBox(height: 12),
            const Text('E-Tickets',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...item.eTickets.map(
              (et) => GestureDetector(
                onTap: () => context.push('/eticket/${et.id}', extra: {
                  'ticket_code': et.ticketCode,
                  'event_title': event?.title ?? '',
                  'ticket_name': item.ticket?.name ?? '',
                  'status': et.status,
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_2,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          et.ticketCode,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalSection(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Total Pembayaran',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          Text(
            order.totalAmount == 0 ? 'Gratis' : formatRupiah(order.totalAmount),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton(OrderModel order) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _cancelling ? null : () => _cancelOrder(order),
        icon: _cancelling
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
              )
            : const Icon(Icons.cancel_outlined, color: AppColors.error),
        label: Text(
          _cancelling ? 'Membatalkan...' : 'Batalkan Order',
          style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.error),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final (color, bg) = switch (status) {
      'paid' => (AppColors.success, AppColors.success.withValues(alpha: 0.1)),
      'pending' => (AppColors.warning, AppColors.warning.withValues(alpha: 0.1)),
      'cancelled' || 'failed' => (AppColors.error, AppColors.error.withValues(alpha: 0.1)),
      _ => (AppColors.textSecondary, AppColors.border),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        switch (status) {
          'paid' => 'Berhasil',
          'pending' => 'Menunggu Bayar',
          'cancelled' => 'Dibatalkan',
          'failed' => 'Gagal',
          _ => status
        },
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
