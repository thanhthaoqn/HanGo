import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/model/trainer_ai_question_models.dart';

class TrainerAiQuestionRepository {
  final String baseUrl = 'http://localhost:8080/api/v1';

  Future<TrainerAiGenerateResponse> generate({
    required String mode,
    required int sectionId,
    required String topicSeed,
    required int quantity,
    int? categoryId,
    int? difficultyId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final uri = Uri.parse('$baseUrl/trainer/questions/ai/generate');

    final body = {
      'mode': mode,
      'sectionId': sectionId,
      'topicSeed': topicSeed,
      'quantity': quantity,
      if (categoryId != null) 'categoryId': categoryId,
      if (difficultyId != null) 'difficultyId': difficultyId,
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
}
