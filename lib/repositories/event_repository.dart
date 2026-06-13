import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../models/category_model.dart';
import '../models/event_model.dart';

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => EventRepository(ref.watch(dioClientProvider)),
);

class EventFilter {
  final String? search;
  final int? categoryId;
  final String? city;
  final String? dateFrom;
  final String? dateTo;
  final double? minPrice;
  final double? maxPrice;
  final bool sortNearest;
  final double? lat;
  final double? lng;
  final int page;

  const EventFilter({
    this.search,
    this.categoryId,
    this.city,
    this.dateFrom,
    this.dateTo,
    this.minPrice,
    this.maxPrice,
    this.sortNearest = false,
    this.lat,
    this.lng,
    this.page = 1,
  });

  Map<String, dynamic> toQuery() => {
        if (search != null && search!.isNotEmpty) 'search': search,
        if (categoryId != null) 'category_id': categoryId,
        if (city != null && city!.isNotEmpty) 'city': city,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        if (sortNearest && lat != null && lng != null) ...{
          'sort_nearest': true,
          'lat': lat,
          'lng': lng,
        },
        'page': page,
      };

  @override
  bool operator ==(Object other) =>
      other is EventFilter &&
      other.search == search &&
      other.categoryId == categoryId &&
      other.city == city &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.sortNearest == sortNearest &&
      other.lat == lat &&
      other.lng == lng &&
      other.page == page;

  @override
  int get hashCode => Object.hash(search, categoryId, city, dateFrom, dateTo,
      minPrice, maxPrice, sortNearest, lat, lng, page);
}

class PaginatedEvents {
  final List<EventModel> data;
  final int currentPage;
  final int lastPage;
  final int total;

  PaginatedEvents({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;
}

class EventRepository {
  final DioClient _client;

  EventRepository(this._client);

  Future<PaginatedEvents> getEvents(EventFilter filter) async {
    try {
      final res = await _client.dio.get(
        '/events',
        queryParameters: filter.toQuery(),
      );
      final data = res.data['data'] as Map<String, dynamic>;
      final items = (data['data'] as List<dynamic>)
          .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return PaginatedEvents(
        data: items,
        currentPage: data['current_page'] as int,
        lastPage: data['last_page'] as int,
        total: data['total'] as int,
      );
    } on Exception catch (e) {
      throw _wrap(e);
    }
  }

  Future<EventModel> getEvent(int id) async {
    try {
      final res = await _client.dio.get('/events/$id');
      return EventModel.fromJson(res.data['data'] as Map<String, dynamic>);
    } on Exception catch (e) {
      throw _wrap(e);
    }
  }

  Future<List<CategoryModel>> getCategories() async {
    try {
      final res = await _client.dio.get('/categories');
      return (res.data['data'] as List<dynamic>)
          .map((c) => CategoryModel.fromJson(c as Map<String, dynamic>))
          .toList();
    } on Exception catch (e) {
      throw _wrap(e);
    }
  }

  Exception _wrap(Object e) {
    if (e is DioException) return ApiException.fromDioError(e);
    if (e is Exception) return e;
    return Exception(e.toString());
  }
}
