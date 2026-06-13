import 'category_model.dart';
import 'ticket_model.dart';
import '../core/utils/format_utils.dart';

class EventModel {
  final int id;
  final String title;
  final String? slug;
  final String? description;
  final String? bannerPath;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? locationName;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String status;
  final CategoryModel? category;
  final List<TicketModel> tickets;

  /// Jarak (km) dari lokasi user — terisi hanya saat backend mengurutkan "terdekat".
  final double? distanceKm;

  EventModel({
    required this.id,
    required this.title,
    this.slug,
    this.description,
    this.bannerPath,
    this.startTime,
    this.endTime,
    this.locationName,
    this.address,
    this.latitude,
    this.longitude,
    required this.status,
    this.category,
    this.tickets = const [],
    this.distanceKm,
  });

  String get bannerUrl => buildImageUrl(bannerPath);

  double? get lowestPrice {
    if (tickets.isEmpty) return null;
    final avail = tickets.where((t) => t.isAvailable).toList();
    final list = avail.isNotEmpty ? avail : tickets;
    list.sort((a, b) => a.price.compareTo(b.price));
    return list.first.price;
  }

  bool get hasAvailableTickets => tickets.any((t) => t.isAvailable);

  factory EventModel.fromJson(Map<String, dynamic> json) => EventModel(
        id: json['id'] as int,
        title: json['title'] as String,
        slug: json['slug'] as String?,
        description: json['description'] as String?,
        bannerPath: json['banner_path'] as String?,
        startTime: json['start_time'] != null
            ? DateTime.tryParse(json['start_time'].toString())
            : null,
        endTime: json['end_time'] != null
            ? DateTime.tryParse(json['end_time'].toString())
            : null,
        locationName: json['location_name'] as String?,
        address: json['address'] as String?,
        latitude: json['latitude'] != null
            ? double.tryParse(json['latitude'].toString())
            : null,
        longitude: json['longitude'] != null
            ? double.tryParse(json['longitude'].toString())
            : null,
        status: json['status'] as String? ?? 'published',
        category: json['category'] != null
            ? CategoryModel.fromJson(json['category'] as Map<String, dynamic>)
            : null,
        tickets: (json['tickets'] as List<dynamic>?)
                ?.map((t) => TicketModel.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
        distanceKm: json['distance_km'] != null
            ? double.tryParse(json['distance_km'].toString())
            : null,
      );
}
