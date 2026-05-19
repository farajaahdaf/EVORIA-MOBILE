import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_model.dart';
import '../repositories/order_repository.dart';

final ordersProvider = FutureProvider<List<OrderModel>>((ref) {
  return ref.watch(orderRepositoryProvider).getOrders();
});

final orderDetailProvider = FutureProvider.family<OrderModel, int>((ref, id) {
  return ref.watch(orderRepositoryProvider).getOrder(id);
});

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({required this.text, required this.isUser})
      : time = DateTime.now();
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
