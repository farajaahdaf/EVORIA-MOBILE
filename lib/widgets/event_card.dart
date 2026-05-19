import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/format_utils.dart';
import '../models/event_model.dart';

class EventCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/events/${event.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBanner(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (event.category != null) _buildCategoryChip(),
                  const SizedBox(height: 6),
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (event.startTime != null) _buildInfoRow(
                    Icons.calendar_today_outlined,
                    formatDate(event.startTime),
                  ),
                  const SizedBox(height: 4),
                  if (event.locationName != null) _buildInfoRow(
                    Icons.location_on_outlined,
                    event.locationName!,
                  ),
                  if (distanceKm != null) ...[
                    const SizedBox(height: 6),
                    _buildDistanceBadge(distanceKm!),
                  ],
                  const SizedBox(height: 10),
                  _buildPriceRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: event.bannerUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: event.bannerUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.border),
                errorWidget: (_, __, ___) => _bannerPlaceholder(),
              )
            : _bannerPlaceholder(),
      ),
    );
  }

  Widget _bannerPlaceholder() => Container(
        color: AppColors.primaryLight,
        child: const Center(
          child: Icon(Icons.event, size: 40, color: AppColors.primary),
        ),
      );

  Widget _buildCategoryChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          event.category!.name,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      );

  Widget _buildDistanceBadge(double km) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.near_me, size: 11, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              km.isInfinite ? 'Lokasi tidak tersedia' : formatDistance(km),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );

  Widget _buildInfoRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

  Widget _buildPriceRow() {
    final price = event.lowestPrice;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          price == null ? '-' : (price == 0 ? 'Gratis' : 'Mulai ${formatRupiah(price)}'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: price == 0 ? AppColors.success : AppColors.primary,
          ),
        ),
        if (!event.hasAvailableTickets)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Habis',
              style: TextStyle(
                  fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}
