import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/location_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/location_provider.dart';
import '../../repositories/event_repository.dart';
import '../../repositories/order_repository.dart';
import '../../widgets/category_selector.dart';
import '../../widgets/event_card.dart';
import '../../widgets/featured_carousel.dart';
import '../../widgets/section_header.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchCtrl = TextEditingController();
  int? _selectedCategoryId;
  String? _selectedCity;
  double? _maxPrice;
  bool _sortByNearest = false;
  String? _userAddress;
  bool _loadingLocation = false;

  /// Posisi efektif untuk sortir Beranda: hanya saat "Terdekat dari saya" aktif.
  /// Sumbernya provider bersama (lihat [userPositionProvider]) sehingga konsisten
  /// dengan lokasi terbaru yang dipakai chatbot.
  Position? get _userPosition =>
      _sortByNearest ? ref.read(userPositionProvider) : null;
  final List<double> _priceOptions = [0, 50000, 100000, 200000, 500000];

  // Cukup sekali per sesi app: jadwalkan ulang reminder dari order yang dibayar.
  static bool _remindersReconciled = false;

  @override
  void initState() {
    super.initState();
    // Re-hydrate state dari filter persisten agar tidak hilang saat Beranda
    // dibuat ulang (mis. setelah pindah tab ke AI lalu kembali).
    final f = ref.read(activeFilterProvider);
    _selectedCategoryId = f.categoryId;
    _selectedCity = f.city;
    _maxPrice = f.maxPrice;
    _sortByNearest = f.sortNearest;
    _searchCtrl.text = f.search ?? '';
    _userAddress = ref.read(userAddressProvider);
    _reconcileReminders();
  }

  /// Ambil order yang sudah dibayar lalu jadwalkan ulang semua reminder event
  /// mendatang. Membuat reminder tetap konsisten setelah app/device restart.
  Future<void> _reconcileReminders() async {
    if (_remindersReconciled) return;
    // Guest belum punya order → lewati (hindari panggilan /orders yang 401).
    if (ref.read(authProvider).status != AuthStatus.authenticated) return;
    _remindersReconciled = true;
    try {
      final orders = await ref.read(orderRepositoryProvider).getOrders();
      final now = DateTime.now();
      final events = <int, ReminderEvent>{};
      for (final order in orders) {
        if (!order.isPaid) continue;
        for (final item in order.orderItems) {
          final ev = item.ticket?.event;
          if (ev?.startTime != null && ev!.startTime!.isAfter(now)) {
            events[ev.id] = ReminderEvent(
              eventId: ev.id,
              title: ev.title,
              start: ev.startTime,
            );
          }
        }
      }
      await NotificationService.instance.syncEventReminders(
        events.values.toList(),
      );
    } catch (_) {
      // Abaikan — reminder akan dicoba lagi saat app dibuka berikutnya.
      _remindersReconciled = false;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    // Sortir "terdekat" dilakukan di backend (atas SEMUA event) → kirim lat/lng.
    final pos = _sortByNearest ? ref.read(userPositionProvider) : null;
    ref.read(activeFilterProvider.notifier).state = EventFilter(
      search: _searchCtrl.text.trim(),
      categoryId: _selectedCategoryId,
      city: _selectedCity,
      maxPrice: _maxPrice,
      sortNearest: _sortByNearest && pos != null,
      lat: pos?.latitude,
      lng: pos?.longitude,
    );
  }

  void _setAddress(String? addr) {
    if (mounted) setState(() => _userAddress = addr);
    ref.read(userAddressProvider.notifier).state = addr;
  }

  void _disableNearestSort() {
    // Provider posisi sengaja tidak dihapus (tetap dipakai chatbot & saat
    // sortir diaktifkan lagi); cukup matikan flag sortir Beranda.
    setState(() => _sortByNearest = false);
    _setAddress(null);
    _applyFilter();
  }

  Future<void> _enableNearestSort() async {
    setState(() => _loadingLocation = true);
    final result = await LocationService.getCurrentPosition();
    if (!mounted) return;

    if (result.isSuccess) {
      final pos = result.position!;
      ref.read(userPositionProvider.notifier).state = pos;
      setState(() => _sortByNearest = true);
      _applyFilter();
      // Pertahankan loading sampai event terdekat benar-benar termuat — supaya
      // tidak ada kedip konten lama sebelum hasil terurut muncul.
      try {
        await ref.read(eventsProvider(ref.read(activeFilterProvider)).future);
      } catch (_) {/* error akan tampil di grid lewat eventsProvider */}
      if (!mounted) return;
      setState(() => _loadingLocation = false);
      LocationService.reverseGeocode(pos.latitude, pos.longitude).then(_setAddress);
      return;
    }

    setState(() => _loadingLocation = false);

    final msg = switch (result.status) {
      LocationResultStatus.serviceDisabled =>
        'Layanan lokasi (GPS) tidak aktif. Aktifkan di pengaturan device.',
      LocationResultStatus.permissionDenied =>
        'Akses lokasi ditolak. Tidak bisa mengurutkan berdasarkan jarak.',
      LocationResultStatus.permissionDeniedForever =>
        'Akses lokasi diblokir permanen. Buka pengaturan aplikasi untuk mengaktifkan.',
      _ => 'Gagal mendapatkan lokasi. Coba lagi.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        action: result.status == LocationResultStatus.permissionDeniedForever
            ? SnackBarAction(
                label: 'Pengaturan',
                onPressed: Geolocator.openAppSettings,
              )
            : null,
      ),
    );
  }

  bool get _hasActiveFilter =>
      _selectedCity != null || _maxPrice != null || _sortByNearest;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final categoriesAsync = ref.watch(categoriesProvider);
    final filter = ref.watch(activeFilterProvider);
    final eventsAsync = ref.watch(eventsProvider(filter));

    // Posisi bersama bisa berubah dari layar lain (chatbot). Pantau agar sortir
    // "Terdekat dari saya" + label lokasi Beranda otomatis ikut lokasi terbaru.
    ref.watch(userPositionProvider);
    ref.listen<Position?>(userPositionProvider, (_, next) {
      if (!_sortByNearest || next == null) return;
      _applyFilter(); // refetch event terdekat dengan koordinat terbaru
      LocationService.reverseGeocode(next.latitude, next.longitude).then(_setAddress);
    });

    final isSearching = (filter.search ?? '').isNotEmpty;
    final showHero = !isSearching &&
        _selectedCategoryId == null &&
        !_hasActiveFilter;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(eventsProvider),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(user?.name),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(
              child: categoriesAsync.when(
                data: (cats) => Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: CategorySelector(
                    categories: cats.map((c) => (c.id, c.name)).toList(),
                    selectedId: _selectedCategoryId,
                    onSelect: (id) {
                      setState(() => _selectedCategoryId = id);
                      _applyFilter();
                    },
                  ),
                ),
                loading: () => const SizedBox(height: 92),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
            SliverToBoxAdapter(child: _buildActiveFilters()),
            SliverToBoxAdapter(child: _buildUserLocationBar()),
            eventsAsync.when(
              data: (result) {
                // Saat menyiapkan "terdekat" (ambil GPS + muat ulang event),
                // tahan loading agar konten lama tidak sempat terlihat.
                if (_loadingLocation) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(60),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                // Sudah terurut dari backend (terdekat) saat sortir aktif.
                final events = result.data;
                return SliverMainAxisGroup(
                  slivers: [
                    if (showHero && events.isNotEmpty) ...[
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      SliverToBoxAdapter(
                        child: FeaturedCarousel(events: events),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    ],
                    SliverToBoxAdapter(
                      child: SectionHeader(
                        title: isSearching ? 'Hasil Pencarian' : 'Jelajahi Event',
                        actionLabel: isSearching ? 'Reset' : null,
                        onAction: isSearching
                            ? () {
                                _searchCtrl.clear();
                                _applyFilter();
                              }
                            : null,
                      ),
                    ),
                    _buildEventGrid(events),
                  ],
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(60),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(child: _buildError(e)),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object e) => Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textLight),
              Gap.h12,
              Text(e.toString(),
                  style: const TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              Gap.h12,
              OutlinedButton(
                onPressed: () => ref.invalidate(eventsProvider),
                style: OutlinedButton.styleFrom(minimumSize: const Size(140, 44)),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );

  Widget _buildAppBar(String? name) {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      floating: true,
      snap: true,
      elevation: 0,
      toolbarHeight: 64,
      titleSpacing: 16,
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', height: 30),
          const Spacer(),
          if (name != null)
            Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.rXl,
                boxShadow: AppShadows.soft,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      gradient: AppGradients.brand,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Gap.w8,
                  Text(
                    'Hai, ${name.split(' ').first}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            )
          else
            // Guest: tombol masuk cepat (browsing tetap bebas tanpa login).
            GestureDetector(
              onTap: () => context.push('/login?returnTo=/home'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppGradients.brand,
                  borderRadius: AppRadius.rXl,
                  boxShadow: AppShadows.glow(AppColors.primary, opacity: 0.28),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.login_rounded, size: 15, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Masuk',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.rMd,
                boxShadow: AppShadows.soft,
              ),
              child: TextField(
                controller: _searchCtrl,
                onSubmitted: (_) => _applyFilter(),
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari event, artis, lokasi...',
                  filled: true,
                  fillColor: Colors.transparent,
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: AppColors.textLight),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          color: AppColors.textLight,
                          onPressed: () {
                            _searchCtrl.clear();
                            _applyFilter();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.rMd,
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.rMd,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
              ),
            ),
          ),
          Gap.w12,
          GestureDetector(
            onTap: _showFilterSheet,
            child: Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                gradient: _hasActiveFilter ? AppGradients.brand : null,
                color: _hasActiveFilter ? null : AppColors.surface,
                borderRadius: AppRadius.rMd,
                boxShadow: _hasActiveFilter
                    ? AppShadows.glow(AppColors.primary, opacity: 0.3)
                    : AppShadows.soft,
              ),
              child: Icon(
                Icons.tune_rounded,
                color: _hasActiveFilter ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserLocationBar() {
    if (_userPosition == null) return const SizedBox.shrink();
    final label = _userAddress ??
        '${_userPosition!.latitude.toStringAsFixed(4)}, ${_userPosition!.longitude.toStringAsFixed(4)}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppRadius.rMd,
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location_rounded, size: 16, color: AppColors.primary),
          Gap.w8,
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontFamily: 'PlusJakartaSans'),
                children: [
                  const TextSpan(
                    text: 'Lokasi Anda: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: label),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: _loadingLocation ? null : _enableNearestSort,
            child: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    final filters = <String>[];
    if (_selectedCity != null) filters.add('Kota: $_selectedCity');
    if (_maxPrice != null) {
      filters.add(_maxPrice == 0 ? 'Gratis' : 'Max: ${formatRupiah(_maxPrice!)}');
    }
    if (_sortByNearest) filters.add('Terdekat dari saya');
    if (filters.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...filters.map(
            (f) => Chip(
              label: Text(f,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
              backgroundColor: AppColors.primaryLight,
              side: BorderSide.none,
              deleteIcon:
                  const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
              onDeleted: () {
                setState(() {
                  if (f.startsWith('Kota')) _selectedCity = null;
                  if (f.startsWith('Max') || f == 'Gratis') _maxPrice = null;
                  if (f == 'Terdekat dari saya') _sortByNearest = false;
                });
                if (f == 'Terdekat dari saya') _setAddress(null);
                _applyFilter();
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventGrid(List<EventModel> events) {
    if (events.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_busy_rounded,
                    size: 48, color: AppColors.primary),
              ),
              Gap.h16,
              const Text(
                'Tidak ada event ditemukan',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Gap.h4,
              const Text(
                'Coba ubah filter atau kata pencarian',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: _sortByNearest ? 0.60 : 0.66,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final ev = events[i];
            // Jarak dihitung backend saat sortir "terdekat" aktif.
            return EventCard(event: ev, distanceKm: ev.distanceKm);
          },
          childCount: events.length,
        ),
      ),
    );
  }

  void _showFilterSheet() {
    String? tempCity = _selectedCity;
    double? tempMax = _maxPrice;
    bool tempNearest = _sortByNearest;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 12,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: AppRadius.rSm,
                  ),
                ),
              ),
              Row(
                children: [
                  const Text('Filter & Urutkan',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setSheetState(() {
                        tempCity = null;
                        tempMax = null;
                        tempNearest = false;
                      });
                    },
                    child: const Text('Reset',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
              Gap.h16,
              const Text('Urutkan',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Gap.h8,
              GestureDetector(
                onTap: _loadingLocation
                    ? null
                    : () => setSheetState(() => tempNearest = !tempNearest),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: tempNearest ? AppGradients.brand : null,
                    color: tempNearest ? null : AppColors.surfaceAlt,
                    borderRadius: AppRadius.rMd,
                    border: Border.all(
                      color: tempNearest ? Colors.transparent : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.near_me_rounded,
                        size: 18,
                        color: tempNearest ? Colors.white : AppColors.textSecondary,
                      ),
                      Gap.w8,
                      Text(
                        'Terdekat dari saya',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tempNearest ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                      if (_loadingLocation) ...[
                        Gap.w8,
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Gap.h20,
              const Text('Kota',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Gap.h8,
              TextFormField(
                initialValue: tempCity,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Jakarta, Bandung',
                  prefixIcon:
                      Icon(Icons.location_on_outlined, color: AppColors.textLight),
                ),
                onChanged: (v) => setSheetState(() => tempCity = v.isEmpty ? null : v),
              ),
              Gap.h20,
              const Text('Harga Maksimum',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Gap.h12,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._priceOptions.map((p) {
                    final label = p == 0 ? 'Gratis' : 'Rp ${(p / 1000).toInt()}rb';
                    final sel = tempMax == p;
                    return GestureDetector(
                      onTap: () => setSheetState(() => tempMax = sel ? null : p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: sel ? AppGradients.brand : null,
                          color: sel ? null : AppColors.surfaceAlt,
                          borderRadius: AppRadius.rSm,
                          border: Border.all(
                            color: sel ? Colors.transparent : AppColors.border,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              Gap.h24,
              ElevatedButton(
                onPressed: () async {
                  setState(() {
                    _selectedCity = tempCity;
                    _maxPrice = tempMax;
                  });
                  _applyFilter();
                  Navigator.pop(ctx);

                  if (tempNearest && !_sortByNearest) {
                    await _enableNearestSort();
                  } else if (!tempNearest && _sortByNearest) {
                    _disableNearestSort();
                  }
                },
                child: const Text('Terapkan Filter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
