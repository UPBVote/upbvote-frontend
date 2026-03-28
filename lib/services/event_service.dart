import '../core/api_client.dart';
import '../models/event_models.dart';

class EventService {
  /// GET /events/ — solo Secretary ve todos los eventos
  static Future<List<EventSummary>> getEvents() async {
    final data = await ApiClient.get('/events/');
    final list = _extractList(data);
    return list.map((e) => EventSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /events/active/ — cualquier usuario autenticado
  static Future<List<EventSummary>> getActiveEvents() async {
    final data = await ApiClient.get('/events/active/');
    final list = _extractList(data);
    return list.map((e) => EventSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /events/{id}/
  static Future<EventDetail> getEventDetail(String id) async {
    final data = await ApiClient.get('/events/$id/');
    return EventDetail.fromJson(data as Map<String, dynamic>);
  }

  /// POST /events/
  /// schedules: [{"type":"UPLOAD","openDate":"...","closeDate":"..."},...]
  static Future<EventSummary> createEvent({
    required String name,
    required DateTime uploadOpen,
    required DateTime uploadClose,
    DateTime? juryOpen,
    DateTime? juryClose,
  }) async {
    final schedules = <Map<String, dynamic>>[
      {
        'type': 'UPLOAD',
        'openDate': uploadOpen.toUtc().toIso8601String(),
        'closeDate': uploadClose.toUtc().toIso8601String(),
      },
      if (juryOpen != null && juryClose != null)
        {
          'type': 'JURY_VOTE',
          'openDate': juryOpen.toUtc().toIso8601String(),
          'closeDate': juryClose.toUtc().toIso8601String(),
        },
    ];
    final data = await ApiClient.post(
      '/events/',
      {'name': name, 'schedules': schedules},
      requiresAuth: true,
    );
    return EventSummary.fromJson(data as Map<String, dynamic>);
  }

  /// PATCH /events/{id}/
  static Future<EventSummary> updateEvent(
      String id, Map<String, dynamic> body) async {
    final data = await ApiClient.patch('/events/$id/', body: body);
    return EventSummary.fromJson(data as Map<String, dynamic>);
  }

  static List _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      if (data['data'] is List) return data['data'] as List;
      if (data['results'] is List) return data['results'] as List;
    }
    return [];
  }
}
