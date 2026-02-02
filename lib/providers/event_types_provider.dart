import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/event_type_model.dart';
import 'repositories_providers.dart';

/// Provider for all event types stream
final eventTypesStreamProvider = StreamProvider<List<EventTypeModel>>((ref) {
  final eventTypeRepository = ref.watch(eventTypeRepositoryProvider);
  return eventTypeRepository.streamAllEventTypes();
});

/// Provider for all event types as a list
final eventTypesProvider = FutureProvider<List<EventTypeModel>>((ref) {
  final eventTypeRepository = ref.watch(eventTypeRepositoryProvider);
  return eventTypeRepository.getAllEventTypes();
});

/// Provider for a specific event type by ID
final eventTypeByIdProvider = FutureProvider.family<EventTypeModel?, String>((ref, typeId) {
  final eventTypeRepository = ref.watch(eventTypeRepositoryProvider);
  return eventTypeRepository.getEventTypeById(typeId);
});

