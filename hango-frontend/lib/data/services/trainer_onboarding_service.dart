import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

import '../../utils/config.dart';

class TrainerOnboardingService {
  final _authService = AuthService();

  static String get baseUrl => EnvConfig.v1BaseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ""}',
    };
  }

  // 1. Upgrade student to trainer
  Future<Map<String, dynamic>> becomeTrainer(String trainerType) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/trainers/become-trainer?trainerType=$trainerType');
      
      final response = await http.post(uri, headers: headers);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Save the new session credentials immediately (updates user roles & token)
        await _authService.saveSession(data);
        
        // Notify application state about token upgrade
        if (AuthService.onLoginSuccess != null) {
          AuthService.onLoginSuccess!(data);
        }
        
        return {'success': true, 'data': data};
      } else {
        final err = jsonDecode(response.body);
        return {'success': false, 'message': err['error'] ?? 'Nâng cấp tài khoản thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // 2. Get Trainer's profile details
  Future<Map<String, dynamic>> getTrainerProfile() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/trainers/profile');
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(utf8.decode(response.bodyBytes))};
      } else {
        final err = jsonDecode(response.body);
        return {'success': false, 'message': err['error'] ?? 'Không thể tải hồ sơ'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // 3. Save profile draft (Auto-Save)
  Future<Map<String, dynamic>> saveProfileDraft(Map<String, dynamic> profileData) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/trainers/profile');
      final response = await http.put(
        uri,
        headers: headers,
        body: jsonEncode(profileData),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(utf8.decode(response.bodyBytes))};
      } else {
        final err = jsonDecode(response.body);
        return {'success': false, 'message': err['error'] ?? 'Lưu bản nháp thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // 4. Submit profile for review
  Future<Map<String, dynamic>> submitProfile(Map<String, dynamic> profileData) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/trainers/profile/submit');
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(profileData),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(utf8.decode(response.bodyBytes))};
      } else {
        final err = jsonDecode(response.body);
        return {'success': false, 'message': err['error'] ?? 'Gửi duyệt hồ sơ thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // 5. Get Trainer profiles for Admin review
  Future<Map<String, dynamic>> getTrainerProfilesForAdmin({String? search, String status = 'ALL'}) async {
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/admin/trainer-profiles?status=$status';
      if (search != null && search.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(search)}';
      }
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(utf8.decode(response.bodyBytes))};
      } else {
        final err = jsonDecode(response.body);
        return {'success': false, 'message': err['error'] ?? 'Lỗi tải danh sách phê duyệt'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // 6. Review Trainer Profile (Admin action)
  Future<Map<String, dynamic>> reviewTrainerProfile(
    int userId, {
    required String status,
    String? adminNotes,
    double? revenueShare,
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/admin/trainer-profiles/$userId/review');
      final response = await http.put(
        uri,
        headers: headers,
        body: jsonEncode({
          'status': status,
          'adminNotes': adminNotes ?? '',
          'revenueShare': revenueShare,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(utf8.decode(response.bodyBytes))};
      } else {
        final err = jsonDecode(response.body);
        return {'success': false, 'message': err['error'] ?? 'Xét duyệt hồ sơ thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
