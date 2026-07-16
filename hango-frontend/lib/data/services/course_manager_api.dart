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
}
