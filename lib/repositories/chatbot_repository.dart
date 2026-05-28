import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../providers/orders_provider.dart';

final chatbotRepositoryProvider = Provider<ChatbotRepository>(
  (ref) => ChatbotRepository(ref.watch(dioClientProvider)),
);

class ChatbotResult {
  final String text;
  final List<ChatEventCard> events;

  const ChatbotResult({required this.text, this.events = const []});
}

class ChatbotRepository {
  final DioClient _client;

  ChatbotRepository(this._client);

  Future<ChatbotResult> sendMessage(String prompt) async {
    try {
      final res = await _client.dio.post('/chatbot', data: {'prompt': prompt});
      final text = res.data['response'] as String? ?? '';
      final rawEvents = res.data['events'] as List<dynamic>? ?? [];
      final events = rawEvents
          .map((e) => ChatEventCard.fromJson(e as Map<String, dynamic>))
          .toList();
      return ChatbotResult(text: text, events: events);
    } on Exception catch (e) {
      if (e is DioException) throw ApiException.fromDioError(e);
      rethrow;
    }
  }
}
