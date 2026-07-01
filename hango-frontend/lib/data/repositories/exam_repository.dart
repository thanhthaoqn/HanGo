import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/exam.dart';

class ExamRepository {
  // Use localhost for Web/Desktop. For Android Emulator, change to 10.0.2.2
  final String baseUrl = 'http://localhost:8080/api/v1';

  Future<List<Exam>> fetchExams({String status = 'All'}) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/exams?status=$status'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((json) => Exam(
          id: json['id'].toString(),
          title: json['title'] ?? '',
          description: json['description'] ?? '',
          status: json['status'] ?? '',
          creatorName: json['creatorName'] ?? 'Unknown',
          questionCount: json['questionCount'] ?? 0,
          durationMinutes: json['durationMinutes'] ?? 0,
          rating: (json['rating'] ?? 0.0).toDouble(),
          learnerCountFormatted: json['learnerCountFormatted'] ?? '0 Learner',
        )).toList();
      } else {
        throw Exception('Failed to load exams: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching exams: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchExamAttempts(String examId) async {
    try {
      final uri = Uri.parse('$baseUrl/exams/$examId/attempts');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception('Failed to load attempts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching attempts: $e');
    }
  }

  Future<Map<String, dynamic>> submitExamAttempt(String examId, double score, Map<String, int> answers) async {
    try {
      final uri = Uri.parse('$baseUrl/exams/$examId/submit');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'score': score,
          'answers': answers.map((key, value) => MapEntry(key.toString(), value)),
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data;
      } else {
        throw Exception('Failed to submit exam: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error submitting exam: $e');
    }
  }
}
