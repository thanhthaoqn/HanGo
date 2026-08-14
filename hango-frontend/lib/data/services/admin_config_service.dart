import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/config.dart';

class AdminConfigService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? prefs.getString('jwt_token');
  }

  Future<Map<String, String>> getAiConfig() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${EnvConfig.v1BaseUrl}/admin/config/ai'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data.map((key, value) => MapEntry(key, value.toString()));
      } else {
        throw Exception('Failed to load AI config: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading AI config: $e');
    }
  }

  Future<void> updateAiConfig(Map<String, String> configs) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('${EnvConfig.v1BaseUrl}/admin/config/ai'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(configs),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update AI config: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating AI config: $e');
    }
  }
}
