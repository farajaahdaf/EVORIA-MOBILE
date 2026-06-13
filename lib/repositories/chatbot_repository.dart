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

  Future<ChatbotResult> sendMessage(
    String prompt, {
    double? lat,
    double? lng,
  }) async {
    try {
      // Chatbot memanggil layanan AI di backend (relatif lambat), jadi beri
      // timeout lebih longgar daripada default Dio (15s) agar tidak putus.
      final res = await _client.dio.post(
        '/chatbot',
        data: {
          'prompt': prompt,
          'lat': ?lat,
          'lng': ?lng,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
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
