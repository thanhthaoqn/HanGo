import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/model/notification_item.dart';
import '../../utils/config.dart';

class NotificationRepository {
  final String baseUrl = EnvConfig.v1BaseUrl;

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<NotificationItem>> getNotifications({int page = 0, int size = 20}) async {
    final headers = await _authHeaders();
    if (!headers.containsKey('Authorization')) return [];

    final response = await http.get(
      Uri.parse('$baseUrl/notifications?page=$page&size=$size'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load notifications');
    }

    final Map<String, dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
    final List<dynamic> content = body['content'] as List<dynamic>? ?? [];
    return content.map((json) => NotificationItem.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<int> getUnreadCount() async {
    final headers = await _authHeaders();
    if (!headers.containsKey('Authorization')) return 0;

    final response = await http.get(
      Uri.parse('$baseUrl/notifications/unread-count'),
      headers: headers,
    );

    if (response.statusCode != 200) return 0;

    final Map<String, dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
    return (body['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markAsRead(int notificationId) async {
    final headers = await _authHeaders();
    if (!headers.containsKey('Authorization')) return;

    await http.put(
      Uri.parse('$baseUrl/notifications/$notificationId/read'),
      headers: headers,
    );
  }

  Future<void> markAllAsRead() async {
    final headers = await _authHeaders();
    if (!headers.containsKey('Authorization')) return;

    await http.put(
      Uri.parse('$baseUrl/notifications/read-all'),
      headers: headers,
    );
  }
}
