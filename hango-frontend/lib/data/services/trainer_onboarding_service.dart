import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../utils/config.dart';
import '../../utils/trainer_onboarding_validation_utils.dart';
import 'auth_service.dart';

class TrainerOnboardingService {
  final _authService = AuthService();

  static const _requestTimeout = Duration(seconds: 20);
  static const _uploadTimeout = Duration(seconds: 60);
  static String get baseUrl => EnvConfig.v1BaseUrl;

  Future<String?> _getToken() async {
    final token = await _authService.getToken();
    return token != null && token.trim().isNotEmpty ? token.trim() : null;
  }

  Future<Map<String, String>?> _getJsonHeaders() async {
    final token = await _getToken();
    if (token == null) return null;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic>? _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _failure(
    http.Response response,
    String fallbackMessage,
  ) {
    final body = _decodeObject(response);
    return {
      'success': false,
      'statusCode': response.statusCode,
      'message': body?['error']?.toString() ?? fallbackMessage,
    };
  }

  Map<String, dynamic> _networkFailure(Object error) {
    if (error is TimeoutException) {
      return {
        'success': false,
        'message':
            'Request timed out. Please check your connection and try again.',
      };
    }
    return {
      'success': false,
      'message': 'Unable to connect to HanGo. Please try again.',
    };
  }

  Map<String, dynamic> _missingSession() => {
    'success': false,
    'statusCode': 401,
    'message': 'Your session has expired. Please sign in again.',
  };

  Future<Map<String, dynamic>> becomeTrainer(String trainerType) async {
    try {
      final headers = await _getJsonHeaders();
      if (headers == null) return _missingSession();
      final uri = Uri.parse(
        '$baseUrl/trainers/become-trainer',
      ).replace(queryParameters: {'trainerType': trainerType});
      final response = await http
          .post(uri, headers: headers)
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return _failure(response, 'Account upgrade failed.');
      }

      final data = _decodeObject(response);
      if (data == null) {
        return {
          'success': false,
          'message': 'The server returned an invalid response.',
        };
      }
      await _authService.saveSession(data);
      AuthService.onLoginSuccess?.call(data);
      return {'success': true, 'data': data};
    } catch (error) {
      return _networkFailure(error);
    }
  }

  Future<Map<String, dynamic>> getTrainerProfile() async {
    try {
      final headers = await _getJsonHeaders();
      if (headers == null) return _missingSession();
      final response = await http
          .get(Uri.parse('$baseUrl/trainers/profile'), headers: headers)
          .timeout(_requestTimeout);
      if (response.statusCode == 200) {
        return {'success': true, 'data': _decodeObject(response) ?? {}};
      }
      return _failure(response, 'Unable to load the trainer profile.');
    } catch (error) {
      return _networkFailure(error);
    }
  }

  Future<Map<String, dynamic>> saveProfileDraft(
    Map<String, dynamic> profileData,
  ) {
    return _sendProfileJson(
      method: 'PUT',
      path: '/trainers/profile',
      profileData: profileData,
      fallbackMessage: 'Unable to save the trainer profile.',
    );
  }

  Future<Map<String, dynamic>> submitProfile(Map<String, dynamic> profileData) {
    return _sendProfileJson(
      method: 'POST',
      path: '/trainers/profile/submit',
      profileData: profileData,
      fallbackMessage: 'Unable to submit the trainer application.',
    );
  }

  Future<Map<String, dynamic>> submitProfileForReview(
    Map<String, dynamic> profileData,
  ) {
    return submitProfile(profileData);
  }

  Future<Map<String, dynamic>> submitCredentialUpdate(
    Map<String, dynamic> profileData,
  ) {
    return _sendProfileJson(
      method: 'POST',
      path: '/trainers/profile/credentials/submit',
      profileData: profileData,
      fallbackMessage: 'Unable to submit the credential update.',
    );
  }

  Future<Map<String, dynamic>> _sendProfileJson({
    required String method,
    required String path,
    required Map<String, dynamic> profileData,
    required String fallbackMessage,
  }) async {
    try {
      final headers = await _getJsonHeaders();
      if (headers == null) return _missingSession();
      final uri = Uri.parse('$baseUrl$path');
      final body = jsonEncode(profileData);
      final response = method == 'POST'
          ? await http
                .post(uri, headers: headers, body: body)
                .timeout(_requestTimeout)
          : await http
                .put(uri, headers: headers, body: body)
                .timeout(_requestTimeout);
      if (response.statusCode == 200) {
        return {'success': true, 'data': _decodeObject(response) ?? {}};
      }
      return _failure(response, fallbackMessage);
    } catch (error) {
      return _networkFailure(error);
    }
  }

  Future<Map<String, dynamic>> uploadTrainerDocument({
    required List<int> bytes,
    required String fileName,
  }) {
    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    final resourceType = isPdf ? 'raw' : 'image';
    return _uploadTrainerFileToCloudinary(
      resourceType: resourceType,
      bytes: bytes,
      fileName: fileName,
      fallbackMessage: 'Unable to upload the trainer document.',
      backendFallbackPath: '/trainers/documents/upload',
    );
  }

  Future<Map<String, dynamic>> uploadTrainerAvatar({
    required List<int> bytes,
    required String fileName,
  }) {
    return _uploadTrainerFileToCloudinary(
      resourceType: 'image',
      bytes: bytes,
      fileName: fileName,
      fallbackMessage: 'Unable to upload the trainer avatar.',
      backendFallbackPath: '/trainers/avatar/upload',
    );
  }

  Future<Map<String, dynamic>> _uploadTrainerFileToCloudinary({
    required String resourceType,
    required List<int> bytes,
    required String fileName,
    required String fallbackMessage,
    required String backendFallbackPath,
  }) async {
    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/diqekap4o/$resourceType/upload',
      );
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'hango_preset'
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: fileName),
        );
      final streamedResponse = await request.send().timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final uploadedUrl = data['secure_url'] ?? data['url'];
        if (uploadedUrl != null && uploadedUrl.toString().isNotEmpty) {
          return {
            'success': true,
            'data': {'url': uploadedUrl.toString()},
          };
        }
      }
    } catch (_) {
      // Fall back to backend upload endpoint
    }

    return _uploadTrainerFile(
      path: backendFallbackPath,
      bytes: bytes,
      fileName: fileName,
      fallbackMessage: fallbackMessage,
    );
  }

  Future<Map<String, dynamic>> _uploadTrainerFile({
    required String path,
    required List<int> bytes,
    required String fileName,
    required String fallbackMessage,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return _missingSession();
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: fileName),
        );
      final streamedResponse = await request.send().timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = _decodeObject(response);
        final url = data?['url']?.toString();
        if (url != null && url.isNotEmpty) {
          return {
            'success': true,
            'data': {'url': url},
          };
        }
      }
      return _failure(
        response,
        trainerUploadFailureMessage(
          statusCode: response.statusCode,
          fallbackMessage: fallbackMessage,
        ),
      );
    } catch (error) {
      return _networkFailure(error);
    }
  }

  Future<Map<String, dynamic>> getTrainerProfilesForAdmin({
    String? search,
    String status = 'ALL',
  }) async {
    try {
      final headers = await _getJsonHeaders();
      if (headers == null) return _missingSession();
      final query = <String, String>{'status': status};
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      final uri = Uri.parse(
        '$baseUrl/admin/trainer-profiles',
      ).replace(queryParameters: query);
      final response = await http
          .get(uri, headers: headers)
          .timeout(_requestTimeout);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return {'success': true, 'data': decoded is List ? decoded : []};
      }
      return _failure(response, 'Unable to load trainer applications.');
    } catch (error) {
      return _networkFailure(error);
    }
  }

  Future<Map<String, dynamic>> reviewTrainerProfile(
    int userId, {
    required String status,
    String? adminNotes,
    double? revenueShare,
  }) {
    return _sendProfileJson(
      method: 'PUT',
      path: '/admin/trainer-profiles/$userId/review',
      profileData: {
        'status': status,
        'adminNotes': adminNotes ?? '',
        'revenueShare': revenueShare,
      },
      fallbackMessage: 'Unable to review the trainer application.',
    );
  }
}
