import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/exam.dart';

class ExamAIRecommendationRepository {
  final String baseUrl = 'http://localhost:8080/api/v1';

  Future<Map<String, dynamic>> recommendCoursesAI({
    required int examAttemptId,
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
      body: jsonEncode({'examAttemptId': examAttemptId}),
    );

    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes);
      throw Exception('AI recommend failed: ${response.statusCode}. $body');
    }

    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}
