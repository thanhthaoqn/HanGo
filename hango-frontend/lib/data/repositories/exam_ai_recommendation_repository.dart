import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/exam.dart';
import '../../utils/config.dart';

class ExamAIRecommendationRepository {
  final String baseUrl = EnvConfig.v1BaseUrl;

  Future<Map<String, dynamic>> recommendCoursesAI({
    required int examAttemptId,
    required String weakestSkill,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final uri = Uri.parse('$baseUrl/exams/ai/recommend-courses');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'examAttemptId': examAttemptId,
        'weakestSkill': weakestSkill,
      }),
    );

    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes);
      throw Exception('AI recommend failed: ${response.statusCode}. $body');
    }

    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}
