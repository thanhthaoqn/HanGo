import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course_manager_dashboard_summary.dart';

class CourseManagerApi {
  static String get baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api/v1/course-manager';
    }
    return 'http://localhost:8080/api/v1/course-manager';
  }

  Future<CourseManagerDashboardSummary> getDashboardSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.get(
      Uri.parse('$baseUrl/dashboard'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return CourseManagerDashboardSummary.fromJson(json);
    } else {
      throw Exception('Failed to load dashboard summary: ${response.statusCode} ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getExamMatrices() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.get(
      Uri.parse('$baseUrl/matrices'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List;
      return decoded.map((item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to get exam matrices: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> createExamMatrix(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.post(
      Uri.parse('$baseUrl/matrices'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create exam matrix: ${response.statusCode} ${response.body}');
    }
  }

  Future<int> countAvailableQuestions(int skillId, int diffId, int catId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.get(
      Uri.parse('$baseUrl/matrices/count-available?skillId=$skillId&diffId=$diffId&catId=$catId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded['count'] as int;
    } else {
      throw Exception('Failed to count available questions: ${response.statusCode}');
    }
  }
}
