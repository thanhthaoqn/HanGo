import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/exam.dart';
import '../../utils/config.dart';

class ExamRepository {
  // Use dynamic baseUrl configuration
  final String baseUrl = EnvConfig.v1BaseUrl;

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

  Future<List<Map<String, dynamic>>> fetchExamQuestions(String examId) async {
    try {
      final uri = Uri.parse('$baseUrl/exams/$examId/questions');
      
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
        throw Exception('Failed to load questions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching questions: $e');
    }
  }

  Future<Map<String, dynamic>> submitExamAttempt(String examId, double score, Map<String, dynamic> answers) async {
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
      throw Exception('Error submitting exam attempt: $e');
    }
  }

  /// The Entry Exam is no longer a hardcoded exam id: a Course Manager flags
  /// one or more exams as entry-exam candidates in Exam Management, and the
  /// backend picks one at random each time. Returns null when none is
  /// configured yet.
  Future<Exam?> fetchEntryExam() async {
    final response = await http.get(Uri.parse('$baseUrl/exams/entry'));
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to load entry exam: ${response.statusCode}');
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    return Exam(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? '',
      creatorName: json['creatorName'] ?? 'Unknown',
      questionCount: json['questionCount'] ?? 0,
      durationMinutes: json['durationMinutes'] ?? 0,
      rating: (json['rating'] ?? 0.0).toDouble(),
      learnerCountFormatted: json['learnerCountFormatted'] ?? '0 Learner',
    );
  }

  /// Whether the learner has completed ANY exam currently flagged as an Entry
  /// Exam (checked against the live flagged set, not a single hardcoded id -
  /// which one gets served is randomized and can change as Course Managers
  /// (un)flag exams over time). Also reports whether one is configured at all.
  Future<Map<String, dynamic>> fetchEntryExamStatus() async {
    final uri = Uri.parse('$baseUrl/exams/entry/status');
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
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)));
    }
    throw Exception('Failed to load entry exam status: ${response.statusCode}');
  }

  Future<List<Map<String, dynamic>>> fetchMyExamAttempts() async {
    try {
      final uri = Uri.parse('$baseUrl/exams/my-attempts');
      
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
        throw Exception('Failed to load my attempts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching my attempts: $e');
    }
  }
}
