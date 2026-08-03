import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/model/ai_health.dart';
import '../domain/model/ai_models.dart';
import '../domain/model/auth_session.dart';
import '../domain/model/course.dart'; // Sử dụng duy nhất model Course này

import '../domain/model/exam_models.dart';
import '../domain/model/recommendation.dart';
import '../domain/model/ai_pathway_models.dart';
import '../presentation/pages/course_manager/question_bank/models/course_manager_question.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode != null ? '$message ($statusCode)' : message;
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

  Future<List<CourseManagerQuestion>> getCourseManagerQuestions({
    required String type,
    String? search,
    String? sortBy,
    int? skillId,
    int? categoryId,
    int? difficultyId,
  }) async {
    final queryParams = <String, String>{
      'type': type,
      if (search != null && search.isNotEmpty) 'search': search,
      if (sortBy != null && sortBy.isNotEmpty) 'sortBy': sortBy,
      if (skillId != null) 'skillId': skillId.toString(),
      if (categoryId != null) 'categoryId': categoryId.toString(),
      if (difficultyId != null) 'difficultyId': difficultyId.toString(),
    };

    // Build URL with query params
    final baseUri = _uri('/api/v1/trainer/question-bank');
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
        .map((json) => CourseManagerQuestion.fromJson(json))
        .toList();
  }

  Future<void> toggleQuestionStatus(int questionId, String newStatus, {bool isGroup = false}) async {
    final queryParams = {'status': newStatus, 'isGroup': isGroup.toString()};
    final baseUri = _uri('/api/v1/trainer/question-bank/$questionId/status');
    final uri = Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.port,
      path: baseUri.path,
      queryParameters: queryParams,
    );
    await _send(http.patch(uri, headers: _headers));
  }

  Future<Map<String, dynamic>> getCourseManagerQuestionDetail(int id, {bool isGroup = false}) async {
    final queryParams = {'isGroup': isGroup.toString()};
    final baseUri = _uri('/api/v1/trainer/question-bank/detail/$id');
    final uri = Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.port,
      path: baseUri.path,
      queryParameters: queryParams,
    );
    final body = await _send(http.get(uri, headers: _headers));
    return body as Map<String, dynamic>;
  }

  Future<void> updateCourseManagerQuestionGroup(int id, Map<String, dynamic> payload, {bool isGroup = false}) async {
    final queryParams = {'isGroup': isGroup.toString()};
    final baseUri = _uri('/api/v1/trainer/question-bank/$id');
    final uri = Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.port,
      path: baseUri.path,
      queryParameters: queryParams,
    );
    await _send(
      http.put(
        uri,
        headers: _headers,
        body: jsonEncode(payload),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getSystemParameters(String type) async {
    final body = await _send(
      http.get(_uri('/api/v1/metadata/parameters?type=$type'), headers: _headers),
    );
    return (body as List? ?? const []).whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getQuestionCategories() async {
    final body = await _send(
      http.get(_uri('/api/v1/metadata/categories'), headers: _headers),
    );
    return (body as List? ?? const []).whereType<Map<String, dynamic>>().toList();
  }

  Future<void> createCourseManagerQuestionGroup(Map<String, dynamic> payload) async {
    await _send(
      http.post(
        _uri('/api/v1/trainer/question-bank'),
        headers: _headers,
        body: jsonEncode(payload),
      ),
    );
  }

  Future<void> saveExamQuestions(int examId, Map<String, dynamic> payload) async {
    await _send(
      http.post(
        _uri('/api/v1/trainer/exams/$examId/questions'),
        headers: _headers,
        body: jsonEncode(payload),
      ),
    );
  }

  Future<Map<String, dynamic>> getExamQuestions(int examId) async {
    final body = await _send(
      http.get(
        _uri('/api/v1/trainer/exams/$examId/questions'),
        headers: _headers,
      ),
    );
    return body as Map<String, dynamic>;
  }

  Future<void> updateExamStatus(int examId, String status) async {
    await _send(
      http.patch(
        _uri('/api/v1/trainer/exams/$examId/status'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      ),
    );
  }

  /// Upload an Excel file to import exams and questions.
  /// Returns the server response map.
  Future<Map<String, dynamic>> importExamExcel(Uint8List fileBytes, String fileName) async {
    final uri = _uri('/api/v1/trainer/exams/import-excel-multiple');
    final request = http.MultipartRequest('POST', uri);
    if (token != null && token!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    final body = response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiFailure(_errorMessage(body), statusCode: response.statusCode);
    }
    return body as Map<String, dynamic>;
  }

  Future<int> createDraftExam(String title) async {
    final payload = {
      'title': title,
      'description': 'Imported from Excel',
      'expectedQuestionCount': 0,
      'passingScore': 0.0,
      'durationMinutes': 0,
    };
    final body = await _send(
      http.post(
        _uri('/api/v1/trainer/exams'),
        headers: _headers,
        body: jsonEncode(payload),
      ),
    );
    // Assuming backend returns the created exam with an 'id' field
    if (body != null && body is Map<String, dynamic> && body.containsKey('id')) {
      return body['id'] as int;
    }
    throw const ApiFailure('Cannot retrieve ID of created exam');
  }

  Future<Uint8List> downloadExamTemplate() async {
    final response = await http.get(
      _uri('/api/v1/trainer/exams/import-excel/template'),
      headers: _headers,
    );
    if (response.statusCode >= 400) {
      throw ApiFailure('Failed to download template', statusCode: response.statusCode);
    }
    return response.bodyBytes;
  }

  Future<Uint8List> downloadQuestionBankTemplate() async {
    final response = await http.get(
      _uri('/api/v1/trainer/question-bank/import-excel/template'),
      headers: _headers,
    );
    if (response.statusCode >= 400) {
      throw ApiFailure('Failed to download template', statusCode: response.statusCode);
    }
    return response.bodyBytes;
  }

  Future<void> deleteExam(int id) async {
    await _send(
      http.delete(
        _uri('/api/v1/trainer/exams/$id'),
        headers: _headers,
      ),
    );
  }
  Future<List<Map<String, dynamic>>> getExamMatrices() async {
    final response = await http.get(
      _uri('/trainer/matrices'),
      headers: _headers,
    );
    if (response.statusCode >= 400) {
      throw ApiFailure('Failed to get matrices', statusCode: response.statusCode);
    }
    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.cast<Map<String, dynamic>>();
  }

  Future<int> generateExamFromMatrix(
      int matrixId,
      String? title,
      String? description,
      int? durationMinutes,
      int? expectedQuestionCount,
      double? passingScore) async {
    final payload = {};
    if (title != null && title.isNotEmpty) payload['title'] = title;
    if (description != null && description.isNotEmpty) payload['description'] = description;
    if (durationMinutes != null) payload['durationMinutes'] = durationMinutes;
    if (expectedQuestionCount != null) payload['expectedQuestionCount'] = expectedQuestionCount;
    if (passingScore != null) payload['passingScore'] = passingScore;

    final body = await _send(
      http.post(
        _uri('/trainer/matrices/$matrixId/generate'),
        headers: _headers,
        body: jsonEncode(payload),
      ),
    );
    if (body != null && body is Map<String, dynamic> && body.containsKey('examId')) {
      return body['examId'] as int;
    }
    throw const ApiFailure('Cannot retrieve ID of generated exam');
  }

  Future<Map<String, dynamic>> createExamMatrix(Map<String, dynamic> data) async {
    final response = await _send(http.post(
      _uri('/trainer/matrices'),
      headers: _headers,
      body: jsonEncode(data),
    ));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw ApiFailure('Failed to create matrix: ${response.statusCode}');
    }
  }

  Future<int> countAvailableQuestions(int skillId, int diffId, int catId) async {
    final response = await _send(http.get(
      _uri('/trainer/matrices/count-available?skillId=$skillId&diffId=$diffId&catId=$catId'),
      headers: _headers,
    ));

    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return json['count'] as int;
    } else {
      throw ApiFailure('Failed to count questions: ${response.statusCode}');
    }
  }
}
