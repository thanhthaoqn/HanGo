import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/model/trainer_ai_question_models.dart';
import '../../domain/model/trainer_ai_exam_models.dart';
import '../../utils/config.dart';

class TrainerAiQuestionRepository {
  final String baseUrl = EnvConfig.v1BaseUrl;

  Future<TrainerAiGenerateResponse> generate({
    required String mode,
    required int sectionId,
    required String topicSeed,
    required int quantity,
    int? categoryId,
    int? difficultyId,
    String? skillType,
    String? groupType,
    bool useSearchGrounding = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final uri = Uri.parse('$baseUrl/trainer/questions/ai/generate');

    final body = {
      'mode': mode,
      'sectionId': sectionId,
      'topicSeed': topicSeed,
      'quantity': quantity,
      'useSearchGrounding': useSearchGrounding,
      'categoryId': ?categoryId,
      'difficultyId': ?difficultyId,
      'skillType': ?skillType,
      'groupType': ?groupType,
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final bodyText = utf8.decode(response.bodyBytes);
      throw Exception('AI generate failed: ${response.statusCode}. $bodyText');
    }

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return TrainerAiGenerateResponse.fromJson(data);
  }

  Future<String> chatExam(List<TrainerExamChatMessage> history) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final uri = Uri.parse('$baseUrl/trainer/questions/ai/exams/chat');

    final body = {
      'history': history.map((e) => e.toJson()).toList(),
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final bodyText = utf8.decode(response.bodyBytes);
      throw Exception('AI chat failed: ${response.statusCode}. $bodyText');
    }

    return utf8.decode(response.bodyBytes);
  }

  Future<TrainerAiExamGenerateResponse> generateExamFromChat(List<TrainerExamChatMessage> history) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final uri = Uri.parse('$baseUrl/trainer/questions/ai/exams/generate-from-chat');

    final body = {
      'history': history.map((e) => e.toJson()).toList(),
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final bodyText = utf8.decode(response.bodyBytes);
      throw Exception('AI exam generate failed: ${response.statusCode}. $bodyText');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return TrainerAiExamGenerateResponse.fromJson(data);
  }
}
