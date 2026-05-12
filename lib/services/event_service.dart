import '../core/api_client.dart';
import '../models/event_models.dart';

class JuryProfileSummary {
  final String id;
  final String profileId;
  final String names;
  final String lastNames;
  final String userName;

  JuryProfileSummary({
    required this.id,
    required this.profileId,
    required this.names,
    required this.lastNames,
    required this.userName,
  });

  String get displayName => '$names $lastNames'.trim();

  factory JuryProfileSummary.fromJson(Map<String, dynamic> j) {
    final user = (j['user'] is Map) ? j['user'] as Map<String, dynamic> : {};
    return JuryProfileSummary(
      id: (j['id'] ?? '').toString(),
      profileId: (j['profileId'] ?? '').toString(),
      names: (j['names'] ?? '').toString(),
      lastNames: (j['lastNames'] ?? '').toString(),
      userName: (user['userName'] ?? '').toString(),
    );
  }
}

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
    List<String> juryIds = const [],
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
    final body = <String, dynamic>{
      'name': name,
      'schedules': schedules,
      if (juryIds.isNotEmpty) 'juryIds': juryIds,
    };
    final data = await ApiClient.post('/events/', body, requiresAuth: true);
    return EventSummary.fromJson(data as Map<String, dynamic>);
  }

  /// PATCH /events/{id}/
  static Future<EventSummary> updateEvent(
      String id, Map<String, dynamic> body) async {
    final data = await ApiClient.patch('/events/$id/', body: body);
    return EventSummary.fromJson(data as Map<String, dynamic>);
  }

  /// DELETE /events/{id}/deactivate/
  static Future<void> deactivateEvent(String eventId) async {
    await ApiClient.delete('/events/$eventId/deactivate/');
  }

  /// POST /events/{id}/juries/
  static Future<void> addJuriesToEvent(String eventId, List<String> profileIds) async {
    await ApiClient.post(
      '/events/$eventId/juries/',
      {'juryIds': profileIds},
      requiresAuth: true,
    );
  }

  /// DELETE /events/{id}/juries/{profileId}/
  static Future<void> removeJuryFromEvent(String eventId, String profileId) async {
    await ApiClient.delete('/events/$eventId/juries/$profileId/');
  }

  /// GET /profiles/juries/?search=X
  static Future<List<JuryProfileSummary>> getJuryProfiles({String? search}) async {
    final q = search != null && search.isNotEmpty ? '?search=${Uri.encodeComponent(search)}' : '';
    final data = await ApiClient.get('/profiles/juries/$q');
    final list = _extractList(data);
    return list.map((e) => JuryProfileSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /events/{id}/schedule/
  static Future<Map<String, dynamic>?> getEventSchedule(String eventId) async {
    try {
      final data = await ApiClient.get('/events/$eventId/schedule/');
      if (data is Map) return data as Map<String, dynamic>;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// POST /events/{id}/schedule/upload/ — multipart PDF
  static Future<void> uploadEventSchedule(String eventId, String filePath) async {
    await ApiClient.postMultipart(
      '/events/$eventId/schedule/upload/',
      fields: {},
      fileField: 'file',
      filePath: filePath,
      mimeType: 'application/pdf',
    );
  }

  /// DELETE /events/{id}/schedule/delete/
  static Future<void> deleteEventSchedule(String eventId) async {
    await ApiClient.delete('/events/$eventId/schedule/delete/');
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
