import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../models/event_model.dart';
import '../../models/ticket_model.dart';
import '../../providers/events_provider.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/order_repository.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final int eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  TicketModel? _selectedTicket;
  int _quantity = 1;
  bool _booking = false;

  Future<void> _bookTicket(EventModel event) async {
    if (_selectedTicket == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tipe tiket terlebih dahulu')),
      );
      return;
    }

    setState(() => _booking = true);
    try {
      final result = await ref.read(orderRepositoryProvider).bookTicket(
            eventId: event.id,
            ticketId: _selectedTicket!.id,
            quantity: _quantity,
          );

      if (!mounted) return;

      if (result.isFree) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/orders');
      } else {
        context.push('/checkout', extra: {
          'snap_token': result.snapToken!,
          'order_number': result.orderNumber,
          'order_id': result.orderId!,
        });
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
                placeholder: (_, __) =>
                    Container(color: AppColors.primaryLight),
                errorWidget: (_, __, ___) =>
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
            color: Colors.black.withOpacity(0.4),
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
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pilih Tiket',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                      ? (_booking ? null : () => _bookTicket(event))
                      : () => context.push('/login'),
                  child: _booking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(isLoggedIn ? 'Beli Tiket' : 'Masuk untuk Membeli'),
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
