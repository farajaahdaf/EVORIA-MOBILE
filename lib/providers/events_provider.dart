import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../models/event_model.dart';
import '../repositories/event_repository.dart';

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) {
  return ref.watch(eventRepositoryProvider).getCategories();
});

final activeFilterProvider =
    StateProvider<EventFilter>((ref) => const EventFilter());

final eventsProvider =
    FutureProvider.family<PaginatedEvents, EventFilter>((ref, filter) {
  return ref.watch(eventRepositoryProvider).getEvents(filter);
});

final eventDetailProvider = FutureProvider.family<EventModel, int>((ref, id) {
  return ref.watch(eventRepositoryProvider).getEvent(id);
});
