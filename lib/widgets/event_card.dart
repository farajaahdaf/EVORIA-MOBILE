import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/format_utils.dart';
import '../models/event_model.dart';

class EventCard extends StatefulWidget {
  final EventModel event;
  final bool compact;
  final double? distanceKm;

  const EventCard({
    super.key,
    required this.event,
    this.compact = false,
    this.distanceKm,
  });

  static String formatDistance(double km) {
    if (km.isInfinite) return '—';
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _pressed = false;

  EventModel get event => widget.event;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/events/${event.id}'),
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.rLg,
            boxShadow: AppShadows.soft,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Gap.h8,
                    if (event.startTime != null)
                      _buildInfoRow(
                        Icons.calendar_today_rounded,
                        formatDate(event.startTime),
                      ),
                    if (event.locationName != null) ...[
                      Gap.h4,
                      _buildInfoRow(
                        Icons.location_on_rounded,
                        event.locationName!,
                      ),
                    ],
                    if (widget.distanceKm != null) ...[
                      Gap.h8,
                      _buildDistanceBadge(widget.distanceKm!),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1),
                    ),
                    _buildPriceRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: event.bannerUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: event.bannerUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, _) =>
                      const ColoredBox(color: AppColors.primaryLight),
                  errorWidget: (_, _, _) => _bannerPlaceholder(),
                )
              : _bannerPlaceholder(),
        ),
        if (event.category != null)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: AppRadius.rSm,
              ),
              child: Text(
                event.category!.name,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        if (!event.hasAvailableTickets)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: AppRadius.rSm,
              ),
              child: const Text(
                'Habis',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _bannerPlaceholder() => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppGradients.brand),
        child: Center(
          child: Icon(Icons.event, size: 36, color: Colors.white38),
        ),
      );

  Widget _buildDistanceBadge(double km) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: AppRadius.rSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.near_me_rounded, size: 11, color: AppColors.primary),
            Gap.w4,
            Text(
              km.isInfinite
                  ? 'Lokasi tidak tersedia'
                  : EventCard.formatDistance(km),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );

  Widget _buildInfoRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 13, color: AppColors.textLight),
          Gap.w6,
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

  Widget _buildPriceRow() {
    final price = event.lowestPrice;
    final isFree = price == 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (price != null && !isFree)
                const Text(
                  'Mulai dari',
                  style: TextStyle(fontSize: 9.5, color: AppColors.textLight),
                ),
              Text(
                price == null
                    ? '-'
                    : (isFree ? 'Gratis' : formatRupiah(price)),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isFree ? AppColors.success : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            gradient: AppGradients.brand,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_outward_rounded,
              size: 16, color: Colors.white),
        ),
      ],
    );
  }
}
