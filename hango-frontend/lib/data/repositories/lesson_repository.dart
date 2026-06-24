import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/model/lesson_detail.dart';

class LessonRepository {
  final String baseUrl = 'http://localhost:8080/api/v1';

  Future<LessonDetail> fetchLessonDetail(int lessonId) async {
    try {
      final uri = Uri.parse('$baseUrl/lessons/$lessonId');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return LessonDetail.fromJson(data);
      } else {
        throw Exception('Failed to load lesson details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching lesson details: $e');
    }
  }

  Future<LessonComment> postComment(int lessonId, int userId, String content, {int? parentCommentId}) async {
    try {
      final uri = Uri.parse('$baseUrl/comments/lesson/$lessonId?userId=$userId'); // Using request param for user id as defined in backend controller
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'content': content,
          if (parentCommentId != null) 'parentCommentId': parentCommentId,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return LessonComment.fromJson(data);
      } else {
        throw Exception('Failed to post comment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error posting comment: $e');
    }
  }

  Future<LessonComment> updateComment(int commentId, int userId, String content) async {
    try {
      final uri = Uri.parse('$baseUrl/comments/$commentId?userId=$userId');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'content': content}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return LessonComment.fromJson(data);
      } else {
        throw Exception('Failed to update comment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating comment: $e');
    }
  }

  Future<void> deleteComment(int commentId, int userId) async {
    try {
      final uri = Uri.parse('$baseUrl/comments/$commentId?userId=$userId');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.delete(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete comment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting comment: $e');
    }
  }

  Future<List<dynamic>> fetchQuizAttempts(int lessonId, int userId) async {
    try {
      final uri = Uri.parse('$baseUrl/lessons/$lessonId/quiz-attempts?userId=$userId');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data;
      } else {
        throw Exception('Failed to load quiz attempts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching quiz attempts: $e');
    }
  }

  Future<dynamic> postQuizAttempt(int lessonId, int userId, double score, Map<int, int> answers) async {
    try {
      final uri = Uri.parse('$baseUrl/lessons/$lessonId/quiz-attempts?userId=$userId');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      // Convert answers map keys to string for JSON serialization
      final Map<String, int> stringKeyAnswers = {};
      answers.forEach((key, value) {
        stringKeyAnswers[key.toString()] = value;
      });

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'score': score,
          'state': 'Finished',
          'answers': stringKeyAnswers,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data;
      } else {
        throw Exception('Failed to submit quiz attempt: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error submitting quiz attempt: $e');
    }
  }

  Future<void> completeLesson(int lessonId, int userId, bool completed) async {
    try {
      final uri = Uri.parse('$baseUrl/lessons/$lessonId/complete?userId=$userId&completed=$completed');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.put(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to complete lesson: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error completing lesson: $e');
    }
  }

  Future<void> likeComment(int commentId, int userId) async {
    try {
      final uri = Uri.parse('$baseUrl/comments/$commentId/like?userId=$userId');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to like comment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error liking comment: $e');
    }
  }

  Future<void> unlikeComment(int commentId, int userId) async {
    try {
      final uri = Uri.parse('$baseUrl/comments/$commentId/unlike?userId=$userId');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to unlike comment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error unliking comment: $e');
    }
  }
}
