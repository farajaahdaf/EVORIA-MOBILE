import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';

final chatbotRepositoryProvider = Provider<ChatbotRepository>(
  (ref) => ChatbotRepository(ref.watch(dioClientProvider)),
);

class ChatbotRepository {
  final DioClient _client;

  ChatbotRepository(this._client);

  Future<String> sendMessage(String prompt) async {
    try {
      final res = await _client.dio.post('/chatbot', data: {'prompt': prompt});
      return res.data['response'] as String? ?? '';
    } on Exception catch (e) {
      if (e is DioException) throw ApiException.fromDioError(e);
      rethrow;
    }
  }
}
