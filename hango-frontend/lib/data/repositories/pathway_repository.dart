import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/learning_pathway.dart';
import '../../utils/config.dart';

class PathwayRepository {
  final String baseUrl = EnvConfig.v1BaseUrl;

  // E2 (spec 20): moi request deu co timeout de UI khong treo vo han
  static const Duration _requestTimeout = Duration(seconds: 30);

  Future<LearningPathway> getMyPathway() async {
    // Doc JWT tu SharedPreferences (key: auth_token) va dinh kem vao header
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
        'Cache-Control': 'no-cache, no-store, must-revalidate',
      },
    ).timeout(_requestTimeout);

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
    bool? onlyFree,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse('$baseUrl/pathways/generate');

    if (token == null || token.isEmpty) {
      throw Exception('Không tìm thấy auth token. Vui lòng đăng nhập lại.');
    }

    // Body gui len backend: examAttemptId la bat buoc, cac truong planning la optional
    final body = {
      'examAttemptId': examAttemptId,
      if (goalName != null) 'goalName': goalName,
      if (targetDate != null) 'targetDate': targetDate,
      if (hoursPerWeek != null) 'hoursPerWeek': hoursPerWeek,
      if (onlyFree != null) 'onlyFree': onlyFree,
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      // Backend tra ve loi (404 attempt khong ton tai, 500 AI loi...) -> nem Exception
      final resBody = utf8.decode(response.bodyBytes);
      throw Exception('Unable to generate pathway: ${response.statusCode}. $resBody');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return LearningPathway.fromJson(data);
  }

  Future<LearningPathway> suggestReroute({required int pathwayId}) async {
    return _postRequestNoBody('$baseUrl/pathways/$pathwayId/reroute/suggestions');
  }

  Future<LearningPathway> acceptReroute({required int pathwayId}) async {
    return _postRequestNoBody('$baseUrl/pathways/$pathwayId/reroute/accept');
  }

  Future<LearningPathway> declineReroute({required int pathwayId}) async {
    return _postRequestNoBody('$baseUrl/pathways/$pathwayId/reroute/decline');
  }

  Future<LearningPathway> reroutePathway({required int pathwayId}) async {
    return _putRequest('$baseUrl/pathways/$pathwayId/reroute');
  }

  Future<LearningPathway> submitNodeMastery({
    required int pathwayId,
    required int nodeId,
    required int score,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse('$baseUrl/pathways/$pathwayId/nodes/$nodeId/mastery');

    if (token == null || token.isEmpty) {
      throw Exception('Không tìm thấy auth token. Vui lòng đăng nhập lại.');
    }

    final body = {
      'score': score,
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      final resBody = utf8.decode(response.bodyBytes);
      throw Exception('Unable to submit mastery: ${response.statusCode}. $resBody');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return LearningPathway.fromJson(data);
  }

  // ===================== MASTERY QUIZ THAT (spec 20 - B4) =====================

  /// Lay de Mastery Quiz cua node (khong kem dap an).
  Future<List<Map<String, dynamic>>> fetchMasteryQuestions({
    required int pathwayId,
    required int nodeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri =
        Uri.parse('$baseUrl/pathways/$pathwayId/nodes/$nodeId/mastery/questions');

    if (token == null || token.isEmpty) {
      throw Exception('Không tìm thấy auth token. Vui lòng đăng nhập lại.');
    }

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      final resBody = utf8.decode(response.bodyBytes);
      throw Exception(
          'Unable to load mastery questions: ${response.statusCode}. $resBody');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.cast<Map<String, dynamic>>();
  }

  /// Nop bai mastery - server tu cham va tra lai pathway da cap nhat.
  Future<Map<String, dynamic>> submitMasteryAnswers({
    required int pathwayId,
    required int nodeId,
    required Map<int, dynamic> answers,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri =
        Uri.parse('$baseUrl/pathways/$pathwayId/nodes/$nodeId/mastery/submit');

    if (token == null || token.isEmpty) {
      throw Exception('Không tìm thấy auth token. Vui lòng đăng nhập lại.');
    }

    // JSON object chi nhan string key -> doi questionId sang chuoi
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'answers':
            answers.map((questionId, optionIndex) => MapEntry(questionId.toString(), optionIndex)),
      }),
    ).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      final resBody = utf8.decode(response.bodyBytes);
      throw Exception(
          'Unable to submit mastery quiz: ${response.statusCode}. $resBody');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return {
      'pathway': LearningPathway.fromJson(data['pathway'] as Map<String, dynamic>),
      'evaluations': data['evaluations'] as List<dynamic>,
    };
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
    ).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes);
      throw Exception('Request failed: ${response.statusCode}. $body');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return LearningPathway.fromJson(data);
  }

  Future<LearningPathway> _postRequestNoBody(String urlStr) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse(urlStr);

    if (token == null || token.isEmpty) {
      throw Exception('Không tìm thấy auth token. Vui lòng đăng nhập lại.');
    }

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(_requestTimeout);

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
    ).timeout(_requestTimeout);

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
    ).timeout(_requestTimeout);

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
    ).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Schedule failed: ${response.statusCode}. ${response.body}');
    }

    return LearningPathway.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }



  Future<LearningPathway> sendMentorAction({
    required int pathwayId,
    required String actionType,
    Map<String, dynamic>? payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse('$baseUrl/pathways/$pathwayId/mentor-action');

    if (token == null || token.isEmpty) {
      throw Exception('Không tìm thấy auth token. Vui lòng đăng nhập lại.');
    }

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'actionType': actionType,
        if (payload != null) 'payload': payload,
      }),
    ).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes);
      throw Exception('Unable to send mentor action: ${response.statusCode}. $body');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return LearningPathway.fromJson(data);
  }

  Future<Map<String, dynamic>> sendChatMessage({
    required int pathwayId,
    required String message,
    int? conversationId,
    int? selectedNodeCourseId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse('$baseUrl/pathways/$pathwayId/chat');

    if (token == null || token.isEmpty) {
      throw Exception('Không tìm thấy auth token. Vui lòng đăng nhập lại.');
    }

    final body = {
      'message': message,
      if (conversationId != null) 'conversation_id': conversationId,
      if (selectedNodeCourseId != null) 'selected_node_course_id': selectedNodeCourseId,
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      final resBody = utf8.decode(response.bodyBytes);
      throw Exception('Unable to send chat message: ${response.statusCode}. $resBody');
    }

    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getChatHistory({
    required int pathwayId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse('$baseUrl/pathways/$pathwayId/chat/history');

    if (token == null || token.isEmpty) {
      throw Exception('Không tìm thấy auth token.');
    }

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to get chat history: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> clearChatHistory({required int pathwayId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse('$baseUrl/pathways/$pathwayId/chat/history');

    if (token == null || token.isEmpty) {
      throw Exception('Không tìm thấy auth token.');
    }

    final response = await http.delete(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(_requestTimeout);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to clear chat history: ${response.statusCode}');
    }
  }
}
