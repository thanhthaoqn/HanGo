import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/model/course.dart';
import '../../domain/model/course_detail.dart';
import '../../domain/model/course_review_summary.dart';

class CourseRepository {
  // Use localhost for Web/Desktop. For Android Emulator, change to 10.0.2.2
  final String baseUrl = 'http://localhost:8080/api/v1';

  Future<List<Course>> fetchCourses({
    String search = '',
    String filterType = 'ALL',
    String difficulty = 'ALL',
  }) async {
    try {
      final queryParams = <String, String>{};
      if (search.isNotEmpty) queryParams['search'] = search;
      if (filterType != 'ALL') queryParams['filterType'] = filterType;
      if (difficulty != 'ALL') queryParams['difficulty'] = difficulty;

      final uri = Uri.parse('$baseUrl/courses').replace(queryParameters: queryParams);
      
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
        return data.map((json) => Course.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load courses: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching courses: $e');
    }
  }

  Future<CourseDetail> fetchCourseDetail(int id) async {
    try {
      final uri = Uri.parse('$baseUrl/courses/$id');
      
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
        return CourseDetail.fromJson(data);
      } else {
        throw Exception('Failed to load course details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching course details: $e');
    }
  }

  Future<CourseReviewSummary> fetchCourseReviews(int id) async {
    try {
      final uri = Uri.parse('$baseUrl/courses/$id/reviews');
      
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
        return CourseReviewSummary.fromJson(data);
      } else {
        throw Exception('Failed to load course reviews: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching course reviews: $e');
    }
  }

  Future<void> enrollCourse(int courseId) async {
    try {
      final uri = Uri.parse('$baseUrl/courses/$courseId/enroll');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to enroll: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error enrolling in course: $e');
    }
  }

  Future<void> unenrollCourse(int courseId) async {
    try {
      final uri = Uri.parse('$baseUrl/courses/$courseId/enroll');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.delete(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to unenroll: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error unenrolling from course: $e');
    }
  }
}
