import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'app_state.dart';

class ApiClient {
  // 10.0.2.2 = host machine from Android emulator; change to your PC's LAN IP for a physical device
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';

  static Map<String, String> _buildHeaders({bool requiresAuth = false}) {
    final headers = {'Content-Type': 'application/json'};
    if (requiresAuth && AppState.token != null) {
      headers['Authorization'] = 'Bearer ${AppState.token}';
    }
    return headers;
  }

  static Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool requiresAuth = false,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _buildHeaders(requiresAuth: requiresAuth),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  static Future<dynamic> get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _buildHeaders(requiresAuth: true),
    );
    return _handleResponse(response);
  }

  static Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _buildHeaders(requiresAuth: true),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  static Future<dynamic> delete(String path) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _buildHeaders(requiresAuth: true),
    );
    if (response.statusCode == 204) return null;
    return _handleResponse(response);
  }

  static Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required String filePath,
    required String mimeType,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    if (AppState.token != null) {
      request.headers['Authorization'] = 'Bearer ${AppState.token}';
    }
    request.fields.addAll(fields);
    request.files.add(await http.MultipartFile.fromPath(
      fileField,
      filePath,
      contentType: MediaType.parse(mimeType),
    ));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  static dynamic _handleResponse(http.Response response) {
    final data = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw ApiException(_extractError(data), response.statusCode);
  }

  static String _extractError(dynamic data) {
    if (data == null) return 'Error desconocido';
    if (data is Map) {
      if (data['detail'] != null) return data['detail'].toString();
      if (data['message'] != null) return data['message'].toString();
      if (data['error'] != null) return data['error'].toString();
      // Django field validation errors: {"field": ["msg"]}
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String) return value;
      }
    }
    return 'Error desconocido';
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
