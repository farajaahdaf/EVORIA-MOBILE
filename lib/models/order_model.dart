import 'order_item_model.dart';

class OrderModel {
  final int id;
  final String orderNumber;
  final int userId;
  final double totalAmount;
  final String status;
  final String? snapToken;
  final String? paymentMethod;
  final DateTime? createdAt;
  final List<OrderItemModel> orderItems;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.userId,
    required this.totalAmount,
    required this.status,
    this.snapToken,
    this.paymentMethod,
    this.createdAt,
    this.orderItems = const [],
  });

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isCancelled => status == 'cancelled' || status == 'failed';
  bool get isFree => paymentMethod == 'free';

  String get statusLabel => switch (status) {
        'paid' => 'Berhasil',
        'pending' => 'Menunggu Pembayaran',
        'cancelled' => 'Dibatalkan',
        'failed' => 'Gagal',
        'refunded' => 'Direfund',
        _ => status,
      };

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        id: json['id'] as int,
        orderNumber: json['order_number'] as String,
        userId: json['user_id'] as int,
        totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0,
        status: json['status'] as String? ?? 'pending',
        snapToken: json['snap_token'] as String?,
        paymentMethod: json['payment_method'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        orderItems: (json['order_items'] as List<dynamic>?)
                ?.map((i) =>
                    OrderItemModel.fromJson(i as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
