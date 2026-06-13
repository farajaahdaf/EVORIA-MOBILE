import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/format_utils.dart';
import '../models/event_model.dart';

/// Hero "Event Unggulan" yang bisa digeser & berganti otomatis — meniru
/// banner carousel di halaman web Evoria (fade + ken-burns + dot indicator).
class FeaturedCarousel extends StatefulWidget {
  final List<EventModel> events;
  const FeaturedCarousel({super.key, required this.events});

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _current = 0;

  List<EventModel> get _slides => widget.events.take(5).toList();

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
    if (_slides.length > 1) _startAuto();
  }

  void _startAuto() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_current + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    if (slides.isEmpty) return const SizedBox.shrink();

    final multi = slides.length > 1;
    return Column(
      children: [
        // Pause auto-advance selagi user menyentuh banner, lalu lanjut lagi —
        // supaya gesekan manual (termasuk mundur ke kanan) tidak "ditarik" balik
        // oleh timer yang selalu maju.
        Listener(
          onPointerDown: (_) => _timer?.cancel(),
          onPointerUp: (_) {
            if (multi) _startAuto();
          },
          onPointerCancel: (_) {
            if (multi) _startAuto();
          },
          child: SizedBox(
            height: 208,
            child: PageView.builder(
              controller: _controller,
              physics: const BouncingScrollPhysics(),
              itemCount: slides.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) {
                final active = i == _current;
                return _Slide(event: slides[i], active: active);
              },
            ),
          ),
        ),
        if (slides.length > 1) ...[
          Gap.h12,
          _Dots(count: slides.length, current: _current),
        ],
      ],
    );
  }
}

class _Slide extends StatelessWidget {
  final EventModel event;
  final bool active;
  const _Slide({required this.event, required this.active});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/events/${event.id}'),
      child: AnimatedScale(
        scale: active ? 1 : 0.94,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: AppRadius.rXl,
            boxShadow: active ? AppShadows.card : AppShadows.soft,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Banner image with slow ken-burns zoom on the active slide.
              if (event.bannerUrl.isNotEmpty)
                AnimatedScale(
                  scale: active ? 1.08 : 1,
                  duration: const Duration(milliseconds: 6000),
                  curve: Curves.easeOut,
                  child: CachedNetworkImage(
                    imageUrl: event.bannerUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        const ColoredBox(color: AppColors.primaryDeep),
                    errorWidget: (_, _, _) => _fallback(),
                  ),
                )
              else
                _fallback(),
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppGradients.bannerScrim),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _badge(),
                    Gap.h8,
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -0.3,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                    ),
                    Gap.h8,
                    Row(
                      children: [
                        if (event.locationName != null) ...[
                          const Icon(Icons.location_on,
                              size: 14, color: Colors.white70),
                          Gap.w4,
                          Flexible(
                            child: Text(
                              event.locationName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Gap.w12,
                        ],
                        if (event.startTime != null) ...[
                          const Icon(Icons.calendar_today,
                              size: 13, color: Colors.white70),
                          Gap.w4,
                          Text(
                            formatDate(event.startTime),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppGradients.brand),
        child: Center(
          child: Icon(Icons.celebration_outlined,
              size: 56, color: Colors.white24),
        ),
      );

  Widget _badge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.92),
          borderRadius: AppRadius.rSm,
        ),
        child: const Text(
          'EVENT UNGGULAN',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      );
}

class _Dots extends StatelessWidget {
  final int count;
  final int current;
  const _Dots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 6,
          width: active ? 22 : 6,
          decoration: BoxDecoration(
            gradient: active ? AppGradients.brandHorizontal : null,
            color: active ? null : AppColors.borderStrong,
            borderRadius: AppRadius.rSm,
          ),
        );
      }),
    );
  }
}
