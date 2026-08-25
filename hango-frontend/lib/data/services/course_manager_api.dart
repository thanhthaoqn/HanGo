import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course_manager_dashboard_summary.dart';
import '../../utils/config.dart';

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
  final num? suggestedPrice;
  final String? priceNote;
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
    this.suggestedPrice,
    this.priceNote,
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
      suggestedPrice: json['suggestedPrice'] is num
          ? json['suggestedPrice'] as num
          : num.tryParse(json['suggestedPrice']?.toString() ?? ''),
      priceNote: json['priceNote']?.toString(),
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
  static String get baseUrl => '${EnvConfig.apiBaseUrl}/api/v1/course-manager';

  // Every request needs an auth token to mean anything against the backend's
  // @PreAuthorize checks. Silently sending the request without one used to
  // just come back as a generic 403 "Access denied" from Spring Security's
  // AccessDeniedHandler (indistinguishable from a real permission gap) —
  // fail fast client-side instead, with a message that says what's actually
  // wrong, so callers can prompt the user to log in again.
  Future<String> _requireToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('Not signed in (no auth token found). Please log in again.');
    }
    return token;
  }

  Future<CourseManagerDashboardSummary> getDashboardSummary() async {
    final token = await _requireToken();

    final response = await http.get(
      Uri.parse('$baseUrl/dashboard'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
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

  Future<Map<String, dynamic>> getReviewCourses({
    String status = 'PENDING',
    int page = 0,
    int size = 10,
  }) async {
    final response = await _get(
      '/courses/review',
      queryParameters: {
        'status': status,
        'page': page.toString(),
        'size': size.toString(),
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      
      List<dynamic> listData = [];
      int totalPages = 1;

      if (data is Map && data.containsKey('content')) {
        listData = data['content'] as List? ?? [];
        totalPages = data['totalPages'] as int? ?? 1;
      } else if (data is List) {
        listData = data;
      } else if (data is Map && data.containsKey('courses')) {
        listData = data['courses'] as List? ?? [];
      }

      final courses = listData
          .map((item) => CourseReviewCourse.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      return {
        'courses': courses,
        'totalPages': totalPages,
      };
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

  Future<void> rejectCourse(int courseId, {String? reason}) async {
    final response = await _post(
      '/courses/$courseId/reject',
      body: reason != null && reason.isNotEmpty
          ? jsonEncode({'reason': reason})
          : null,
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to reject course: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> hideCourse(int courseId) async {
    final response = await _post('/courses/$courseId/hide');
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to hide course: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> unhideCourse(int courseId) async {
    final response = await _post('/courses/$courseId/unhide');
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to unhide course: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<int> generateExamFromMatrix(
      int matrixId,
      String? title,
      String? description,
      int? durationMinutes,
      int? expectedQuestionCount,
      double? passingScore,
      {int? questionSourceType}) async {
    final payload = {};
    if (title != null && title.isNotEmpty) payload['title'] = title;
    if (description != null && description.isNotEmpty) payload['description'] = description;
    if (durationMinutes != null) payload['durationMinutes'] = durationMinutes;
    if (expectedQuestionCount != null) payload['expectedQuestionCount'] = expectedQuestionCount;
    if (passingScore != null) payload['passingScore'] = passingScore;
    if (questionSourceType != null) payload['questionSourceType'] = questionSourceType;

    final response = await _post('/matrices/$matrixId/generate', body: jsonEncode(payload));
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['examId'] as int;
    }
    throw Exception('Failed to generate exam: ${response.statusCode} ${response.body}');
  }

  Future<List<dynamic>> getExamsForReview(String status) async {
    final response = await _get('/exams/review?status=$status');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List;
      return decoded;
    }
    throw Exception(
      'Failed to get exams for review: ${response.statusCode} ${response.body}',
    );
  }

  Future<void> publishExam(int examId) async {
    final response = await _post('/exams/$examId/publish');
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to publish exam: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> rejectExam(int examId, {String? reason}) async {
    final response = await _post(
      '/exams/$examId/reject',
      body: reason != null && reason.isNotEmpty
          ? jsonEncode({'reason': reason})
          : null,
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to reject exam: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<dynamic> getExamDetails(int examId) async {
    // Note: uses trainer endpoint because COURSE_MANAGER role is allowed to call it to view full exam details
    final token = await _requireToken();

    final uri = Uri.parse(
      '${EnvConfig.apiBaseUrl}/api/v1/trainer/exams/$examId/questions',
    );
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    throw Exception(
      'Failed to get exam details: ${response.statusCode} ${response.body}',
    );
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

  Future<void> toggleMatrixStatus(int id) async {
    final response = await _put('/matrices/$id/toggle-public');
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to toggle matrix status: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> updateExamMatrix(int id, Map<String, dynamic> data) async {
    final response = await _put('/matrices/$id', body: jsonEncode(data));
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update exam matrix: ${response.statusCode} ${response.body}',
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

  Future<List<Map<String, dynamic>>> getCategories() async {
    final token = await _requireToken();

    final metadataUrl = baseUrl.replaceAll(
      '/course-manager',
      '/metadata/categories',
    );

    final response = await http.get(
      Uri.parse(metadataUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List;
      return decoded.map((item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to get categories: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getSystemParameters(String type) async {
    final token = await _requireToken();

    // The backend uses /api/v1/metadata/parameters
    final metadataUrl = baseUrl.replaceAll(
      '/course-manager',
      '/metadata/parameters',
    );

    final response = await http.get(
      Uri.parse('$metadataUrl?type=$type'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List;
      return decoded.map((item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception(
        'Failed to get system parameters: ${response.statusCode}',
      );
    }
  }

  Future<void> updateExamInfo(int examId, Map<String, dynamic> data) async {
    final token = await _requireToken();
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}/api/v1/trainer/exams/$examId/info');
    final response = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update exam info: ${response.statusCode}');
    }
  }

  Future<http.Response> _get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final token = await _requireToken();
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: queryParameters);

    return http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  Future<http.Response> _post(String path, {Object? body}) async {
    final token = await _requireToken();

    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );
  }

  Future<http.Response> _put(String path, {Object? body}) async {
    final token = await _requireToken();

    return http.put(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );
  }
}
