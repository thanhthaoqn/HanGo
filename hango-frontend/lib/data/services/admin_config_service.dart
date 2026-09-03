import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      final url = '${EnvConfig.v1BaseUrl}/admin/config/ai';
      debugPrint('[AdminConfigService] GET $url with token present: ${token != null && token.isNotEmpty}');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );
      debugPrint('[AdminConfigService] GET $url status: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data.map((key, value) => MapEntry(key, value.toString()));
      } else {
        throw Exception('Failed to load AI config: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[AdminConfigService] Error in getAiConfig: $e');
      throw Exception('Error loading AI config: $e');
    }
  }

  Future<void> updateAiConfig(Map<String, String> configs) async {
    try {
      final token = await _getToken();
      final url = '${EnvConfig.v1BaseUrl}/admin/config/ai';
      debugPrint('[AdminConfigService] PUT $url with token present: ${token != null && token.isNotEmpty}, payload: $configs');
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(configs),
      );
      debugPrint('[AdminConfigService] PUT $url status: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to update AI config: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[AdminConfigService] Error in updateAiConfig: $e');
      throw Exception('Error updating AI config: $e');
    }
  }
}
