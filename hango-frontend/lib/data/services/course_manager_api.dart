import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course_manager_dashboard_summary.dart';

class CourseReviewCourse {
  final int id;
  final String title;
  final String code;
  final String creatorName;
  final String categoryName;
  final String difficultyName;
  final String description;
  final String objectives;
  final num price;
  final String version;
  final String status;
  final String thumbnailUrl;
  final int lessonsCount;
  final int sectionsCount;
  final DateTime? submittedAt;
  final List<dynamic> sessions;

  CourseReviewCourse({
    required this.id,
    required this.title,
    required this.code,
    required this.creatorName,
    required this.categoryName,
    required this.difficultyName,
    required this.description,
    required this.objectives,
    required this.price,
    required this.version,
    required this.status,
    required this.thumbnailUrl,
    required this.lessonsCount,
    required this.sectionsCount,
    required this.submittedAt,
    required this.sessions,
  });

  factory CourseReviewCourse.fromJson(Map<String, dynamic> json) {
    final sessions = json['sessions'] as List? ?? const [];
    final lessonsCount =
        json['lessonsCount'] ??
        sessions.fold<int>(0, (total, section) {
          final lessons = section is Map ? section['lessons'] as List? : null;
          return total + (lessons?.length ?? 0);
        });

    return CourseReviewCourse(
      id: (json['id'] ?? 0) as int,
      title: json['title']?.toString() ?? 'Untitled course',
      code: json['code']?.toString() ?? 'N/A',
      creatorName: json['creatorName']?.toString() ?? 'Unknown trainer',
      categoryName: json['categoryName']?.toString() ?? 'Uncategorized',
      difficultyName: json['difficultyName']?.toString() ?? 'N/A',
      description: json['description']?.toString() ?? '',
      objectives: json['objectives']?.toString() ?? '',
      price: json['price'] is num
          ? json['price'] as num
          : num.tryParse(json['price']?.toString() ?? '') ?? 0,
      version: json['version']?.toString() ?? 'v1.0',
      status: json['status']?.toString() ?? 'PENDING',
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
      lessonsCount: lessonsCount is int
          ? lessonsCount
          : int.tryParse(lessonsCount.toString()) ?? 0,
      sectionsCount: json['sectionsCount'] is int
          ? json['sectionsCount'] as int
          : sessions.length,
      submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? ''),
      sessions: sessions,
    );
  }
}

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
      throw Exception(
        'Failed to load dashboard summary: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<List<CourseReviewCourse>> getReviewCourses({
    String status = 'PENDING',
  }) async {
    final response = await _get(
      '/courses/review',
      queryParameters: {'status': status},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final list = data is List ? data : (data['courses'] as List?) ?? const [];
      return (list as List)
          .map(
            (item) => CourseReviewCourse.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    }

    throw Exception(
      'Failed to load course review queue: ${response.statusCode} ${response.body}',
    );
  }

  Future<CourseReviewCourse> getReviewCourseDetail(int courseId) async {
    final response = await _get('/courses/$courseId/review-detail');

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return CourseReviewCourse.fromJson(
        Map<String, dynamic>.from(data as Map),
      );
    }

    throw Exception(
      'Failed to load course detail: ${response.statusCode} ${response.body}',
    );
  }

  Future<void> publishCourse(int courseId) async {
    final response = await _post('/courses/$courseId/publish');
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to publish course: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> rejectCourse(int courseId) async {
    final response = await _post('/courses/$courseId/reject');
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to reject course: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getExamMatrices() async {
    final response = await _get('/matrices');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List;
      return decoded.map((item) => item as Map<String, dynamic>).toList();
    }

    throw Exception(
      'Failed to get exam matrices: ${response.statusCode} ${response.body}',
    );
  }

  Future<void> createExamMatrix(Map<String, dynamic> data) async {
    final response = await _post('/matrices', body: jsonEncode(data));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Failed to create exam matrix: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<int> countAvailableQuestions(
    int skillId,
    int diffId,
    int catId,
  ) async {
    final response = await _get(
      '/matrices/count-available',
      queryParameters: {
        'skillId': skillId.toString(),
        'diffId': diffId.toString(),
        'catId': catId.toString(),
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded['count'] as int;
    }

    throw Exception(
      'Failed to count available questions: ${response.statusCode}',
    );
  }

  Future<http.Response> _get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: queryParameters);

    return http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  Future<http.Response> _post(String path, {Object? body}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: body,
    );
  }
}
