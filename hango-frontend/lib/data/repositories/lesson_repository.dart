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

  Future<LessonComment> postComment(int lessonId, int userId, String content) async {
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
        body: jsonEncode({'content': content}),
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
}
