import 'ticket_model.dart';
import 'e_ticket_model.dart';

class OrderItemModel {
  final int id;
  final int orderId;
  final int ticketId;
  final int quantity;
  final double price;
  final double subtotal;
  final TicketModel? ticket;
  final List<ETicketModel> eTickets;

  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.ticketId,
    required this.quantity,
    required this.price,
    required this.subtotal,
    this.ticket,
    this.eTickets = const [],
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) => OrderItemModel(
        id: json['id'] as int,
        orderId: json['order_id'] as int,
        ticketId: json['ticket_id'] as int,
        quantity: json['quantity'] as int,
        price: double.tryParse(json['price'].toString()) ?? 0,
        subtotal: double.tryParse(json['subtotal'].toString()) ?? 0,
        ticket: json['ticket'] != null
            ? TicketModel.fromJson(json['ticket'] as Map<String, dynamic>)
            : null,
        eTickets: (json['e_tickets'] as List<dynamic>?)
                ?.map((e) => ETicketModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
