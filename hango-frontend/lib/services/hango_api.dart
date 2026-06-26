import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/model/ai_health.dart';
import '../domain/model/ai_models.dart';
import '../domain/model/auth_session.dart';
import '../domain/model/course.dart'; // Sử dụng duy nhất model Course này

import '../domain/model/exam_models.dart';
import '../domain/model/recommendation.dart';
import '../domain/model/ai_pathway_models.dart';
import '../presentation/pages/trainer/question_bank/models/trainer_question.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class HangoApi {
  HangoApi({required this.baseUrl, this.token});

  String baseUrl;
  String? token;

  Uri _uri(String path) =>
      Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$path');

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> _send(Future<http.Response> request) async {
    late final http.Response response;
    try {
      response = await request.timeout(const Duration(seconds: 18));
    } on Exception {
      throw const ApiFailure(
        'Không kết nối được backend. Kiểm tra server Spring Boot và base URL.',
      );
    }

    final body = response.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiFailure(_errorMessage(body), statusCode: response.statusCode);
    }
    return body;
  }

  String _errorMessage(dynamic body) {
    if (body is Map<String, dynamic>) {
      return body['message'] as String? ??
          body['error'] as String? ??
          body['detail'] as String? ??
          'Yêu cầu chưa thành công.';
    }
    return 'Yêu cầu chưa thành công.';
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final body = await _send(
      http.post(
        _uri('/api/auth/login'),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      ),
    );
    return AuthSession.fromJson(body as Map<String, dynamic>);
  }

  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final body = await _send(
      http.post(
        _uri('/api/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'fullName': fullName,
          'email': email,
          'password': password,
        }),
      ),
    );
    return AuthSession.fromJson(body as Map<String, dynamic>);
  }

  Future<List<Exam>> listExams() async {
    final body = await _send(http.get(_uri('/api/exams'), headers: _headers));
    return (body as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Exam.fromJson)
        .toList();
  }

  // === ĐÃ SỬA: Thay đổi CourseSummary thành Course ===
  Future<List<Course>> listCourses() async {
    final body = await _send(http.get(_uri('/api/courses'), headers: _headers));
    return (body as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          Course.fromJson,
        ) // Parse thẳng thành class Course bằng hàm từ json cũ của bạn
        .toList();
  }

  // === ĐÃ SỬA: Thay đổi CourseDetail thành Course để tránh lỗi compile thiếu file ===
  Future<Course> courseDetail(int courseId) async {
    final body = await _send(
      http.get(_uri('/api/courses/$courseId'), headers: _headers),
    );
    return Course.fromJson(body as Map<String, dynamic>);
  }

  Future<ExamAttempt> startExam(int examId) async {
    final body = await _send(
      http.post(_uri('/api/exams/$examId/start'), headers: _headers),
    );
    return ExamAttempt.fromJson(body as Map<String, dynamic>);
  }

  Future<ExamResult> submitExam({
    required int attemptId,
    required Map<int, String?> answers,
  }) async {
    final body = await _send(
      http.post(
        _uri('/api/exams/submit'),
        headers: _headers,
        body: jsonEncode({
          'attemptId': attemptId,
          'answers': answers.entries
              .map(
                (entry) => {
                  'questionId': entry.key,
                  'selectedOption': entry.value,
                },
              )
              .toList(),
        }),
      ),
    );
    return ExamResult.fromJson(body as Map<String, dynamic>);
  }

  Future<List<ExamAttempt>> history() async {
    final body = await _send(
      http.get(_uri('/api/exams/history'), headers: _headers),
    );
    return (body as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ExamAttempt.fromJson)
        .toList();
  }

  Future<List<CourseRecommendation>> recommendations() async {
    final body = await _send(
      http.get(_uri('/api/recommendations/courses'), headers: _headers),
    );
    return (body as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CourseRecommendation.fromJson)
        .toList();
  }

  Future<AiCoursePathwayResponse> fetchAiPathway() async {
    final body = await _send(
      http.get(_uri('/api/recommendations/ai-pathway'), headers: _headers),
    );
    return AiCoursePathwayResponse.fromJson(body as Map<String, dynamic>);
  }

  // 🟢 ĐÃ SỬA: Thêm /v1 vào các endpoint AI để đi qua được bộ lọc SecurityConfig
  Future<List<AiConversation>> conversations() async {
    final body = await _send(
      http.get(_uri('/api/v1/ai-assistant/conversations'), headers: _headers),
    );
    return (body as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AiConversation.fromJson)
        .toList();
  }

  // 🟢 ĐÃ SỬA: Thêm /v1 vào endpoint lấy trạng thái sức khỏe AI
  Future<AiHealth> aiStatus() async {
    final body = await _send(
      http.get(_uri('/api/v1/ai-assistant/status'), headers: _headers),
    );
    return AiHealth.fromJson(body as Map<String, dynamic>);
  }

  // 🟢 ĐÃ SỬA: Thêm /v1 vào endpoint gửi tin nhắn hội thoại với AI
  Future<SendMessageResponse> sendMessage({
    required int lessonId,
    required String message,
    int? conversationId,
  }) async {
    final body = await _send(
      http.post(
        _uri('/api/v1/ai-assistant/messages'),
        headers: _headers,
        body: jsonEncode({
          'lessonId': lessonId,
          'message': message,
          if (conversationId != null) 'conversationId': conversationId,
        }),
      ),
    );
    return SendMessageResponse.fromJson(body as Map<String, dynamic>);
  }

  Future<List<TrainerQuestion>> getTrainerQuestions({
    required String type,
    String? search,
    String? sortBy,
  }) async {
    final queryParams = <String, String>{
      'type': type,
      if (search != null && search.isNotEmpty) 'search': search,
      if (sortBy != null && sortBy.isNotEmpty) 'sortBy': sortBy,
    };
    
    // Build URL with query params
    final baseUri = _uri('/api/v1/trainer/questions');
    final uri = Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.port,
      path: baseUri.path,
      queryParameters: queryParams,
    );

    final body = await _send(http.get(uri, headers: _headers));
    return (body as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TrainerQuestion.fromJson)
        .toList();
  }
}
