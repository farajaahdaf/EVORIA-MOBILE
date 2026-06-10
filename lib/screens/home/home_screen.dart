import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/location_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/events_provider.dart';
import '../../repositories/event_repository.dart';
import '../../repositories/order_repository.dart';
import '../../widgets/event_card.dart';

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
  Position? _userPosition;
  String? _userAddress;
  bool _loadingLocation = false;
  final List<double> _priceOptions = [0, 50000, 100000, 200000, 500000];

  // Cukup sekali per sesi app: jadwalkan ulang reminder dari order yang dibayar.
  static bool _remindersReconciled = false;

  @override
  void initState() {
    super.initState();
    _reconcileReminders();
  }

  /// Ambil order yang sudah dibayar lalu jadwalkan ulang semua reminder event
  /// mendatang. Membuat reminder tetap konsisten setelah app/device restart.
  Future<void> _reconcileReminders() async {
    if (_remindersReconciled) return;
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
    ref.read(activeFilterProvider.notifier).state = EventFilter(
      search: _searchCtrl.text.trim(),
      categoryId: _selectedCategoryId,
      city: _selectedCity,
      maxPrice: _maxPrice,
    );
  }

  void _disableNearestSort() {
    setState(() {
      _sortByNearest = false;
      _userPosition = null;
      _userAddress = null;
    });
  }

  Future<void> _enableNearestSort() async {
    setState(() => _loadingLocation = true);
    final result = await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() => _loadingLocation = false);

    if (result.isSuccess) {
      final pos = result.position!;
      setState(() {
        _userPosition = pos;
        _sortByNearest = true;
      });
      final addr = await LocationService.reverseGeocode(
        pos.latitude,
        pos.longitude,
      );
      if (mounted) setState(() => _userAddress = addr);
      return;
    }

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

  List<EventModel> _sortedEvents(List<EventModel> events) {
    if (!_sortByNearest || _userPosition == null) return events;
    final pos = _userPosition!;
    final withDist = events.map((e) {
      final hasCoord = e.latitude != null && e.longitude != null;
      final dist = hasCoord
          ? LocationService.distanceKm(
              pos.latitude, pos.longitude, e.latitude!, e.longitude!)
          : double.infinity;
      return (event: e, dist: dist);
    }).toList()
      ..sort((a, b) => a.dist.compareTo(b.dist));
    return withDist.map((p) => p.event).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final categoriesAsync = ref.watch(categoriesProvider);
    final filter = ref.watch(activeFilterProvider);
    final eventsAsync = ref.watch(eventsProvider(filter));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(user?.name),
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverToBoxAdapter(
            child: categoriesAsync.when(
              data: (cats) => _buildCategoryFilter(cats.map((c) => (c.id, c.name)).toList()),
              loading: () => const SizedBox(height: 52),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ),
          SliverToBoxAdapter(child: _buildActiveFilters()),
          SliverToBoxAdapter(child: _buildUserLocationBar()),
          eventsAsync.when(
            data: (result) => _buildEventGrid(_sortedEvents(result.data)),
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.wifi_off, size: 48, color: AppColors.textLight),
                      const SizedBox(height: 12),
                      Text(e.toString(),
                          style: const TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(eventsProvider),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(120, 40)),
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildAppBar(String? name) {
    return SliverAppBar(
      backgroundColor: AppColors.surface,
      floating: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.border,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.border),
      ),
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', height: 32),
          const Spacer(),
          if (name != null)
            Text(
              'Hai, ${name.split(' ').first}!',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => _applyFilter(),
              decoration: InputDecoration(
                hintText: 'Cari event, artis, lokasi...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applyFilter();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showFilterSheet,
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: (_selectedCity != null ||
                        _maxPrice != null ||
                        _sortByNearest)
                    ? AppColors.primary
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                Icons.tune,
                color: (_selectedCity != null ||
                        _maxPrice != null ||
                        _sortByNearest)
                    ? Colors.white
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(List<(int, String)> categories) {
    return Container(
      color: AppColors.surface,
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: categories.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            final selected = _selectedCategoryId == null;
            return _buildCategoryChip(null, 'Semua', selected);
          }
          final (id, name) = categories[i - 1];
          return _buildCategoryChip(id, name, _selectedCategoryId == id);
        },
      ),
    );
  }

  Widget _buildCategoryChip(int? id, String label, bool selected) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategoryId = selected ? null : id);
        _applyFilter();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildUserLocationBar() {
    if (_userPosition == null) return const SizedBox.shrink();
    final label = _userAddress ??
        '${_userPosition!.latitude.toStringAsFixed(4)}, ${_userPosition!.longitude.toStringAsFixed(4)}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: AppColors.primary),
                children: [
                  const TextSpan(
                    text: 'Lokasi Anda: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: label),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: _loadingLocation ? null : _enableNearestSort,
            child: const Icon(Icons.refresh, size: 16, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    final filters = <String>[];
    if (_selectedCity != null) filters.add('Kota: $_selectedCity');
    if (_maxPrice != null) {
      filters.add(_maxPrice == 0 ? 'Gratis' : 'Max: Rp ${_maxPrice!.toInt()}');
    }
    if (_sortByNearest) filters.add('Terdekat dari saya');
    if (filters.isEmpty) return const SizedBox.shrink();

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Wrap(
        spacing: 8,
        children: [
          ...filters.map(
            (f) => Chip(
              label: Text(f,
                  style: const TextStyle(fontSize: 12, color: AppColors.primary)),
              backgroundColor: AppColors.primaryLight,
              deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
              onDeleted: () {
                setState(() {
                  if (f.startsWith('Kota')) _selectedCity = null;
                  if (f.startsWith('Max') || f == 'Gratis') _maxPrice = null;
                  if (f == 'Terdekat dari saya') {
                    _sortByNearest = false;
                    _userPosition = null;
                    _userAddress = null;
                  }
                });
                _applyFilter();
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventGrid(List<EventModel> events) {
    if (events.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: Column(
            children: [
              Icon(Icons.event_busy, size: 56, color: AppColors.textLight),
              SizedBox(height: 12),
              Text(
                'Tidak ada event ditemukan',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Coba ubah filter atau kata pencarian',
                style: TextStyle(color: AppColors.textLight, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: _sortByNearest ? 0.58 : 0.65,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final ev = events[i];
            double? dist;
            if (_userPosition != null &&
                ev.latitude != null &&
                ev.longitude != null) {
              dist = LocationService.distanceKm(
                _userPosition!.latitude,
                _userPosition!.longitude,
                ev.latitude!,
                ev.longitude!,
              );
            } else if (_userPosition != null) {
              dist = double.infinity;
            }
            return EventCard(event: ev, distanceKm: dist);
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
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Filter',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
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
              const SizedBox(height: 16),
              const Text('Urutkan',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _loadingLocation
                    ? null
                    : () => setSheetState(() => tempNearest = !tempNearest),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: tempNearest ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: tempNearest ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.near_me_outlined,
                        size: 18,
                        color: tempNearest ? Colors.white : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Terdekat dari saya',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tempNearest
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (_loadingLocation) ...[
                        const SizedBox(width: 8),
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
              const SizedBox(height: 16),
              const Text('Kota',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: tempCity,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Jakarta, Bandung',
                  prefixIcon:
                      Icon(Icons.location_on_outlined, color: AppColors.textLight),
                ),
                onChanged: (v) => setSheetState(() => tempCity = v.isEmpty ? null : v),
              ),
              const SizedBox(height: 16),
              const Text('Harga Maksimum',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ..._priceOptions.map((p) {
                    final label = p == 0 ? 'Gratis' : 'Rp ${(p / 1000).toInt()}rb';
                    final sel = tempMax == p;
                    return GestureDetector(
                      onTap: () => setSheetState(() => tempMax = sel ? null : p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sel ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 24),
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
