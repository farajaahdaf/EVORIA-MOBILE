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
    duration: const Duration(milliseconds: 700),
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
      alignment: 0.05,
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
          SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.success),
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
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
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
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMainInfo(event),
                  _buildDescription(event),
                  if (event.latitude != null && event.longitude != null)
                    _buildMap(event),
                  if (event.tickets.isNotEmpty) _buildTicketSection(event),
                  const SizedBox(height: 80),
                ],
              ),
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
      expandedHeight: 200,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.ink,
      foregroundColor: Colors.white,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: _circleButton(
          Icons.arrow_back_ios_new_rounded,
          () => context.pop(),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            event.bannerUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: event.bannerUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        const ColoredBox(color: AppColors.primaryDeep),
                    errorWidget: (_, _, _) => _heroFallback(),
                  )
                : _heroFallback(),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppGradients.bannerScrim),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroFallback() => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppGradients.brand),
        child: Center(
          child: Icon(Icons.celebration_outlined, size: 72, color: Colors.white24),
        ),
      );

  Widget _circleButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, size: 17, color: Colors.white),
        ),
      );

  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        padding: padding ?? const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.rXl,
          boxShadow: AppShadows.soft,
        ),
        child: child,
      );

  Widget _buildMainInfo(EventModel event) {
    return _card(
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.category != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: AppGradients.brand,
                borderRadius: AppRadius.rSm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(categoryIcon(event.category!.name),
                      size: 12, color: Colors.white),
                  Gap.w4,
                  Text(
                    event.category!.name,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          Gap.h12,
          Text(
            event.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.25,
              letterSpacing: -0.4,
            ),
          ),
          Gap.h16,
          _infoRow(Icons.calendar_today_rounded, 'Tanggal & Waktu',
              formatDateTime(event.startTime)),
          if (event.endTime != null) ...[
            Gap.h12,
            _infoRow(Icons.access_time_rounded, 'Selesai',
                formatDateTime(event.endTime)),
          ],
          if (event.locationName != null) ...[
            Gap.h12,
            _infoRow(
              Icons.location_on_rounded,
              'Lokasi',
              '${event.locationName}${event.address != null ? '\n${event.address}' : ''}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: AppRadius.rSm,
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildDescription(EventModel event) {
    if (event.description == null || event.description!.isEmpty) {
      return const SizedBox.shrink();
    }
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Tentang Event'),
          Gap.h12,
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

  Widget _sectionTitle(String text) => Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: const BoxDecoration(
              gradient: AppGradients.brand,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
          Gap.w8,
          Text(text,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3)),
        ],
      );

  Widget _buildMap(EventModel event) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Lokasi Event'),
          Gap.h12,
          ClipRRect(
            borderRadius: AppRadius.rMd,
            child: SizedBox(
              height: 180,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(event.latitude!, event.longitude!),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('event'),
                    position: LatLng(event.latitude!, event.longitude!),
                    infoWindow:
                        InfoWindow(title: event.locationName ?? event.title),
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
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.rXl,
            border: Border.all(
              color: Color.lerp(
                  Colors.transparent, AppColors.primary, glow)!,
              width: 1.6,
            ),
            boxShadow: glow > 0
                ? AppShadows.glow(AppColors.primary, opacity: glow * 0.3)
                : AppShadows.soft,
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionTitle('Pilih Tiket'),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _highlightAnim,
                builder: (_, _) => _highlightAnim.value > 0.05
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary
                              .withValues(alpha: _highlightAnim.value),
                          borderRadius: AppRadius.rSm,
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
          Gap.h12,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unavailable
              ? AppColors.surfaceAlt
              : (selected ? AppColors.primaryLight : AppColors.surface),
          borderRadius: AppRadius.rMd,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: (selected && !unavailable) ? AppGradients.brand : null,
                color: (selected && !unavailable)
                    ? null
                    : AppColors.surfaceAlt,
                borderRadius: AppRadius.rSm,
              ),
              child: Icon(
                Icons.confirmation_number_rounded,
                size: 20,
                color: (selected && !unavailable)
                    ? Colors.white
                    : AppColors.textLight,
              ),
            ),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.name,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: unavailable
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
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
            Gap.w8,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ticket.isFree ? 'Gratis' : formatRupiah(ticket.price),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: unavailable
                        ? AppColors.textLight
                        : (ticket.isFree ? AppColors.success : AppColors.primary),
                  ),
                ),
                if (selected && !unavailable) ...[
                  const SizedBox(height: 2),
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 18),
                ],
              ],
            ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: Color(0x141B2A4A), blurRadius: 20, offset: Offset(0, -6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedTicket != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Jumlah Tiket',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: AppRadius.rSm,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _qtyBtn(Icons.remove_rounded, () {
                        if (_quantity > 1) setState(() => _quantity--);
                      }),
                      SizedBox(
                        width: 36,
                        child: Text('$_quantity',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                      _qtyBtn(Icons.add_rounded, () {
                        if (_quantity < 5) setState(() => _quantity++);
                      }),
                    ],
                  ),
                ),
              ],
            ),
            Gap.h12,
          ],
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Total',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    price == 0 ? 'Gratis' : formatRupiah(price),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Gap.w16,
              Expanded(child: _gradientCta(event, isLoggedIn)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gradientCta(EventModel event, bool isLoggedIn) {
    return GestureDetector(
      onTap: _booking
          ? null
          : (isLoggedIn ? () => _bookTicket(event) : () => context.push('/login')),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: AppGradients.brand,
          borderRadius: AppRadius.rMd,
          boxShadow: AppShadows.glow(AppColors.primary, opacity: 0.32),
        ),
        alignment: Alignment.center,
        child: _booking
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.4),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLoggedIn
                        ? Icons.shopping_bag_rounded
                        : Icons.login_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  Gap.w6,
                  Text(
                    isLoggedIn ? 'Beli Tiket' : 'Masuk untuk Beli',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
      );
}
