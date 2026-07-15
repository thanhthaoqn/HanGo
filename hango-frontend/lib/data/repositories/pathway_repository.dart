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

  Future<LearningPathway> generatePathway({
    required int examAttemptId,
    String? goalName,
    String? targetDate,
    int? hoursPerWeek,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse('$baseUrl/pathways/generate');

    if (token == null || token.isEmpty) {
      throw Exception('Không tìm thấy auth token. Vui lòng đăng nhập lại.');
    }

    final body = {
      'examAttemptId': examAttemptId,
      if (goalName != null) 'goalName': goalName,
      if (targetDate != null) 'targetDate': targetDate,
      if (hoursPerWeek != null) 'hoursPerWeek': hoursPerWeek,
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final resBody = utf8.decode(response.bodyBytes);
      throw Exception('Unable to generate pathway: ${response.statusCode}. $resBody');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return LearningPathway.fromJson(data);
  }

  Future<LearningPathway> suggestReroute({required int pathwayId}) async {
    return _putRequest('$baseUrl/pathways/$pathwayId/reroute/suggestions');
  }

  Future<LearningPathway> acceptReroute({required int pathwayId}) async {
    return _putRequest('$baseUrl/pathways/$pathwayId/reroute/accept');
  }

  Future<LearningPathway> declineReroute({required int pathwayId}) async {
    return _putRequest('$baseUrl/pathways/$pathwayId/reroute/decline');
  }

  Future<LearningPathway> reroutePathway({required int pathwayId}) async {
    // Legacy fallback, mapped to suggestReroute
    return suggestReroute(pathwayId: pathwayId);
  }

  Future<LearningPathway> _putRequest(String urlStr) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse(urlStr);

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
      throw Exception('Request failed: ${response.statusCode}. $body');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return LearningPathway.fromJson(data);
  }

  Future<Map<String, dynamic>> getProgressSnapshot({required int pathwayId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse('$baseUrl/pathways/$pathwayId/progress-snapshot');

    if (token == null || token.isEmpty) throw Exception('Auth missing');

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get snapshot: ${response.statusCode}');
    }

    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<Map<String, dynamic>> getScheduleStatus({required int pathwayId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse('$baseUrl/pathways/$pathwayId/schedule-status');

    if (token == null || token.isEmpty) throw Exception('Auth missing');

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get schedule status: ${response.statusCode}');
    }

    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<LearningPathway> schedulePathway({
    required int pathwayId,
    required String goalName,
    required String targetDate,
    required int hoursPerWeek,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse('$baseUrl/pathways/$pathwayId/schedule');

    if (token == null || token.isEmpty) {
      throw Exception('Không tìm thấy auth token.');
    }

    final body = {
      'goalName': goalName,
      'targetDate': targetDate,
      'hoursPerWeek': hoursPerWeek,
    };

    final response = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Schedule failed: ${response.statusCode}. ${response.body}');
    }

    return LearningPathway.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<MergePreview> mergePreview(List<int> courseIds) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse('$baseUrl/pathways/merge-preview');

    if (token == null || token.isEmpty) throw Exception('Auth missing');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(courseIds),
    );

    if (response.statusCode != 200) {
      throw Exception('Merge preview failed: ${response.statusCode}. ${response.body}');
    }

    return MergePreview.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<LearningPathway> mergeConfirm(int pathwayId, MergePreview preview) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse('$baseUrl/pathways/$pathwayId/merge-confirm');

    if (token == null || token.isEmpty) throw Exception('Auth missing');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(preview.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Merge confirm failed: ${response.statusCode}. ${response.body}');
    }

    return LearningPathway.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
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
