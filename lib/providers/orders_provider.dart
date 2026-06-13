import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_model.dart';
import '../repositories/order_repository.dart';

final ordersProvider = FutureProvider<List<OrderModel>>((ref) {
  return ref.watch(orderRepositoryProvider).getOrders();
});

final orderDetailProvider = FutureProvider.family<OrderModel, int>((ref, id) {
  return ref.watch(orderRepositoryProvider).getOrder(id);
});

class ChatEventCard {
  final int id;
  final String title;
  final String? date;
  final String? location;
  final double? lowestPrice;
  final String? bannerUrl;
  final String? category;

  /// Jarak (km) dari lokasi user saat ini — hanya terisi untuk query "terdekat".
  final double? distanceKm;

  const ChatEventCard({
    required this.id,
    required this.title,
    this.date,
    this.location,
    this.lowestPrice,
    this.bannerUrl,
    this.category,
    this.distanceKm,
  });

  factory ChatEventCard.fromJson(Map<String, dynamic> j) => ChatEventCard(
        id: j['id'] as int,
        title: j['title'] as String,
        date: j['date'] as String?,
        location: j['location'] as String?,
        lowestPrice: j['lowest_price'] != null
            ? double.tryParse(j['lowest_price'].toString())
            : null,
        bannerUrl: j['banner_url'] as String?,
        category: j['category'] as String?,
        distanceKm: j['distance_km'] != null
            ? double.tryParse(j['distance_km'].toString())
            : null,
      );
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final List<ChatEventCard> events;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.events = const [],
  }) : time = DateTime.now();
}

class ChatbotNotifier extends StateNotifier<List<ChatMessage>> {
  ChatbotNotifier() : super([]);

  void addMessage(ChatMessage msg) => state = [...state, msg];

  void clear() => state = [];
}

final chatbotMessagesProvider =
    StateNotifierProvider<ChatbotNotifier, List<ChatMessage>>(
  (_) => ChatbotNotifier(),
);
