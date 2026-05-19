import 'event_model.dart';

class TicketModel {
  final int id;
  final int eventId;
  final String name;
  final double price;
  final int quota;
  final int availableQty;
  final EventModel? event;

  TicketModel({
    required this.id,
    required this.eventId,
    required this.name,
    required this.price,
    required this.quota,
    required this.availableQty,
    this.event,
  });

  bool get isAvailable => availableQty > 0;
  bool get isFree => price == 0;

  factory TicketModel.fromJson(Map<String, dynamic> json) => TicketModel(
        id: json['id'] as int,
        eventId: json['event_id'] as int,
        name: json['name'] as String,
        price: double.tryParse(json['price'].toString()) ?? 0,
        quota: json['quota'] as int? ?? 0,
        availableQty: json['available_qty'] as int? ?? 0,
        event: json['event'] != null
            ? EventModel.fromJson(json['event'] as Map<String, dynamic>)
            : null,
      );
}
