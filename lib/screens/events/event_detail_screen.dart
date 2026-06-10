import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/format_utils.dart';
import '../../models/event_model.dart';
import '../../models/ticket_model.dart';
import '../../providers/events_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../repositories/order_repository.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final int eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  TicketModel? _selectedTicket;
  int _quantity = 1;
  bool _booking = false;

  final _scrollCtrl = ScrollController();
  final _ticketKey = GlobalKey();
  late final AnimationController _highlightCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _highlightAnim =
      CurvedAnimation(parent: _highlightCtrl, curve: Curves.easeInOut);

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _highlightCtrl.dispose();
    super.dispose();
  }

  void _scrollToTickets() {
    final ctx = _ticketKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.0,
    ).then((_) {
      _highlightCtrl.forward(from: 0).then((_) => _highlightCtrl.reverse());
    });
  }

  Future<void> _bookTicket(EventModel event) async {
    if (_selectedTicket == null) {
      _scrollToTickets();
      return;
    }
    if (_booking) return;
    setState(() => _booking = true);

    try {
      final result = await ref.read(orderRepositoryProvider).bookTicket(
            eventId: event.id,
            ticketId: _selectedTicket!.id,
            quantity: _quantity,
          );

      // Notifikasi setiap pembelian — dipicu saat order dibuat, tidak
      // menunggu hasil pembayaran (berlaku untuk tiket gratis & berbayar).
      await NotificationService.instance.showOrderPlaced(
        eventTitle: event.title,
        orderKey: result.orderNumber,
        isFree: result.isFree,
      );

      if (!mounted) return;

      if (result.isFree) {
        ref.invalidate(ordersProvider);
        await NotificationService.instance.scheduleEventReminders(
          ReminderEvent(
            eventId: event.id,
            title: event.title,
            start: event.startTime,
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: AppColors.success),
        );
        context.go('/orders');
      } else {
        context.push('/checkout', extra: {
          'snap_token': result.snapToken!,
          'order_number': result.orderNumber,
          'order_id': result.orderId!,
          'payment_expires_at': result.paymentExpiresAt?.toIso8601String(),
          'payment_timeout_minutes': result.paymentTimeoutMinutes,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));

    return eventAsync.when(
      data: (event) => _buildContent(event),
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.surface),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Detail Event')),
        body: Center(child: Text(e.toString())),
      ),
    );
  }

  Widget _buildContent(EventModel event) {
    final isLoggedIn = ref.watch(authProvider).status == AuthStatus.authenticated;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          _buildHero(event),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMainInfo(event),
                const Divider(height: 1),
                _buildDescription(event),
                if (event.latitude != null && event.longitude != null) ...[
                  const Divider(height: 1),
                  _buildMap(event),
                ],
                if (event.tickets.isNotEmpty) ...[
                  const Divider(height: 1),
                  _buildTicketSection(event),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: event.tickets.isNotEmpty
          ? _buildBottomBar(event, isLoggedIn)
          : null,
    );
  }

  Widget _buildHero(EventModel event) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: AppColors.surface,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: event.bannerUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: event.bannerUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: AppColors.primaryLight),
                errorWidget: (_, _, _) =>
                    Container(color: AppColors.primaryLight,
                      child: const Center(child: Icon(Icons.event, size: 60, color: AppColors.primary)),
                    ),
              )
            : Container(
                color: AppColors.primaryLight,
                child: const Center(
                  child: Icon(Icons.event, size: 80, color: AppColors.primary),
                ),
              ),
      ),
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
      ),
    );
  }

  Widget _buildMainInfo(EventModel event) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.category != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                event.category!.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            event.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          _infoRow(Icons.calendar_today_outlined, formatDateTime(event.startTime)),
          if (event.endTime != null) ...[
            const SizedBox(height: 8),
            _infoRow(Icons.access_time_outlined,
                'Selesai ${formatDateTime(event.endTime)}'),
          ],
          const SizedBox(height: 8),
          if (event.locationName != null)
            _infoRow(Icons.location_on_outlined,
                '${event.locationName}${event.address != null ? '\n${event.address}' : ''}'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      );

  Widget _buildDescription(EventModel event) {
    if (event.description == null || event.description!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tentang Event',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
            event.description!,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(EventModel event) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lokasi Event',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 200,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(event.latitude!, event.longitude!),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('event'),
                    position: LatLng(event.latitude!, event.longitude!),
                    infoWindow: InfoWindow(title: event.locationName ?? event.title),
                  ),
                },
                zoomControlsEnabled: false,
                scrollGesturesEnabled: false,
                myLocationButtonEnabled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketSection(EventModel event) {
    return AnimatedBuilder(
      animation: _highlightAnim,
      builder: (_, child) {
        final glow = _highlightAnim.value;
        return Container(
          key: _ticketKey,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              left: BorderSide(
                color: AppColors.primary.withValues(alpha: glow * 0.8),
                width: 3 * glow,
              ),
            ),
            boxShadow: glow > 0
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: glow * 0.15),
                      blurRadius: 12 * glow,
                      spreadRadius: 2 * glow,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(20),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _highlightAnim,
            builder: (_, child) => Transform.translate(
              // Efek shake kecil saat highlight
              offset: Offset(
                _highlightAnim.value > 0
                    ? 4 * (_highlightAnim.value < 0.5
                        ? _highlightAnim.value * 2
                        : (1 - _highlightAnim.value) * 2) *
                        (_highlightCtrl.lastElapsedDuration?.inMilliseconds ?? 0) % 2 == 0
                        ? 1.0
                        : -1.0
                    : 0,
                0,
              ),
              child: child!,
            ),
            child: Row(
              children: [
                const Text(
                  'Pilih Tiket',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                AnimatedBuilder(
                  animation: _highlightAnim,
                  builder: (_, _) => _highlightAnim.value > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(
                                alpha: _highlightAnim.value * 0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Pilih dulu',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...event.tickets.map((t) => _buildTicketOption(t)),
        ],
      ),
    );
  }

  Widget _buildTicketOption(TicketModel ticket) {
    final selected = _selectedTicket?.id == ticket.id;
    final unavailable = !ticket.isAvailable;

    return GestureDetector(
      onTap: unavailable ? null : () => setState(() => _selectedTicket = ticket),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unavailable
              ? AppColors.background
              : (selected ? AppColors.primaryLight : AppColors.surface),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: unavailable ? AppColors.textLight : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ticket.isFree ? 'Gratis' : formatRupiah(ticket.price),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: unavailable
                          ? AppColors.textLight
                          : (ticket.isFree ? AppColors.success : AppColors.primary),
                    ),
                  ),
                  Text(
                    unavailable
                        ? 'Habis terjual'
                        : '${ticket.availableQty} tiket tersisa',
                    style: TextStyle(
                      fontSize: 12,
                      color: unavailable ? AppColors.error : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected && !unavailable)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(EventModel event, bool isLoggedIn) {
    final price = _selectedTicket != null
        ? _selectedTicket!.price * _quantity
        : event.lowestPrice ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedTicket != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Jumlah', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    _qtyBtn(Icons.remove, () {
                      if (_quantity > 1) setState(() => _quantity--);
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('$_quantity',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    _qtyBtn(Icons.add, () {
                      if (_quantity < 5) setState(() => _quantity++);
                    }),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      price == 0 ? 'Gratis' : formatRupiah(price),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: isLoggedIn
                      ? () => _bookTicket(event)
                      : () => context.push('/login'),
                  child: Text(isLoggedIn ? 'Beli Tiket' : 'Masuk untuk Membeli'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.textPrimary),
        ),
      );
}
