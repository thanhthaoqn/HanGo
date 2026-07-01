import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/learning_pathway.dart';

class PathwayRepository {
  final String baseUrl = 'http://localhost:8080/api/v1';

  Future<LearningPathway> getMyPathway() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse('$baseUrl/pathways/me');

    if (token == null || token.isEmpty) {
      throw Exception('Không tìm thấy auth token. Vui lòng đăng nhập lại.');
    }

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes);
      throw Exception('Unable to load pathway: ${response.statusCode}. $body');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return LearningPathway.fromJson(data);
  }

  Future<LearningPathway> reroutePathway({required int pathwayId, required int quizScore}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse('$baseUrl/pathways/$pathwayId/reroute?quizScore=$quizScore');

    if (token == null || token.isEmpty) {
      throw Exception('Không tìm thấy auth token. Vui lòng đăng nhập lại.');
    }

    final response = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes);
      throw Exception('Unable to reroute pathway: ${response.statusCode}. $body');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return LearningPathway.fromJson(data);
  }

  Future<String> chatWithMentor({required int pathwayId, required String message}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse('$baseUrl/pathways/$pathwayId/chat');

    if (token == null || token.isEmpty) {
      throw Exception('Không tìm thấy auth token. Vui lòng đăng nhập lại.');
    }

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'message': message}),
    );

    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes);
      throw Exception('Unable to chat with mentor: ${response.statusCode}. $body');
    }

    return utf8.decode(response.bodyBytes);
  }
}
