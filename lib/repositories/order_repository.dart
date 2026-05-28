import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../models/order_model.dart';

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ref.watch(dioClientProvider)),
);

class BookingResult {
  final String orderNumber;
  final int? orderId;
  final String? snapToken;
  final String? redirectUrl;
  final bool isFree;
  final String message;
  /// ISO-8601 timestamp: kapan order pending ini akan di-cancel otomatis.
  final DateTime? paymentExpiresAt;
  final int paymentTimeoutMinutes;

  BookingResult({
    required this.orderNumber,
    this.orderId,
    this.snapToken,
    this.redirectUrl,
    required this.isFree,
    required this.message,
    this.paymentExpiresAt,
    this.paymentTimeoutMinutes = 30,
  });
}

class OrderRepository {
  final DioClient _client;

  OrderRepository(this._client);

  Future<BookingResult> bookTicket({
    required int eventId,
    required int ticketId,
    required int quantity,
  }) async {
    try {
      final res = await _client.dio.post(
        '/events/$eventId/book',
        data: {'ticket_id': ticketId, 'quantity': quantity},
      );
      final expiresAtStr = res.data['payment_expires_at'] as String?;
      return BookingResult(
        orderNumber: res.data['order_number'] as String,
        orderId: res.data['order_id'] as int?,
        snapToken: res.data['snap_token'] as String?,
        redirectUrl: res.data['redirect_url'] as String?,
        isFree: res.data['is_free'] as bool? ?? false,
        message: res.data['message'] as String? ?? '',
        paymentExpiresAt: expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null,
        paymentTimeoutMinutes: res.data['payment_timeout_minutes'] as int? ?? 30,
      );
    } on Exception catch (e) {
      throw _wrap(e);
    }
  }

  Future<List<OrderModel>> getOrders() async {
    try {
      final res = await _client.dio.get('/orders');
      final data = res.data['data'] as Map<String, dynamic>;
      return (data['data'] as List<dynamic>)
          .map((o) => OrderModel.fromJson(o as Map<String, dynamic>))
          .toList();
    } on Exception catch (e) {
      throw _wrap(e);
    }
  }

  Future<OrderModel> getOrder(int id) async {
    try {
      final res = await _client.dio.get('/orders/$id');
      return OrderModel.fromJson(res.data['data'] as Map<String, dynamic>);
    } on Exception catch (e) {
      throw _wrap(e);
    }
  }

  Future<OrderModel> syncOrderStatus(int orderId) async {
    try {
      final res = await _client.dio.post('/orders/$orderId/sync');
      return OrderModel.fromJson(res.data['data'] as Map<String, dynamic>);
    } on Exception catch (e) {
      throw _wrap(e);
    }
  }

  /// Batalkan order pending dan kembalikan stok tiket langsung.
  /// Dipanggil saat user tutup/error Snap tanpa konfirmasi bayar.
  Future<void> cancelOrder(int orderId) async {
    try {
      await _client.dio.post('/orders/$orderId/cancel');
    } on Exception catch (_) {
      // Best-effort; abaikan error (order akan di-cancel otomatis setelah timeout).
    }
  }

  Exception _wrap(Object e) {
    if (e is DioException) return ApiException.fromDioError(e);
    if (e is Exception) return e;
    return Exception(e.toString());
  }
}
