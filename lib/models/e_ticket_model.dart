class ETicketModel {
  final int id;
  final int orderItemId;
  final String ticketCode;
  final String? qrCodePath;
  final String status;
  final DateTime? usedAt;

  ETicketModel({
    required this.id,
    required this.orderItemId,
    required this.ticketCode,
    this.qrCodePath,
    required this.status,
    this.usedAt,
  });

  bool get isUsed => status == 'used';
  bool get isCancelled => status == 'cancelled';
  bool get isValid => status == 'issued' || status == 'active';

  factory ETicketModel.fromJson(Map<String, dynamic> json) => ETicketModel(
        id: json['id'] as int,
        orderItemId: json['order_item_id'] as int,
        ticketCode: json['ticket_code'] as String,
        qrCodePath: json['qr_code_path'] as String?,
        status: json['status'] as String? ?? 'issued',
        usedAt: json['used_at'] != null
            ? DateTime.tryParse(json['used_at'].toString())
            : null,
      );
}
