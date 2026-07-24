import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/file_picker_helper.dart';

import '../../utils/config.dart';
import '../../utils/cart_manager.dart';

class AuthService {
  // 🚀 DÒNG THÊM MỚI: Cổng phát tín hiệu (Callback static) để AppState đứng từ xa lắng nghe
  static Function(Map<String, dynamic>)? onLoginSuccess;

  // Use dynamic baseUrl configuration
  static String get baseUrl => EnvConfig.authBaseUrl;

  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userFullNameKey = 'user_fullname';
  static const String _userRolesKey = 'user_roles';
  static const String _userAvatarUrlKey = 'user_avatar_url';

  // Perform login request
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveSession(data);

        // 🔥 PHÁT TÍN HIỆU NGẦM: Báo cho AppState biết để cập nhật UI ngay lập tức
        if (onLoginSuccess != null) {
          onLoginSuccess!(data);
        }

        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static String? cachedFullName;
  static String? cachedEmail;
  static String? cachedAvatarUrl;
  static bool? cachedIsLoggedIn;
  static final ValueNotifier<int> userChangeNotifier = ValueNotifier<int>(0);

  static void notifyUserChanged() {
    userChangeNotifier.value++;
  }

  // Save session details
  Future<void> saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, data['token']);
    await prefs.setInt(_userIdKey, data['id']);
    await prefs.setString(_userEmailKey, data['email']);
    await prefs.setString(_userFullNameKey, data['fullName']);
    await prefs.setStringList(_userRolesKey, List<String>.from(data['roles']));
    if (data['avatarUrl'] != null) {
      await prefs.setString(_userAvatarUrlKey, data['avatarUrl']);
      cachedAvatarUrl = data['avatarUrl'];
    } else {
      await prefs.remove(_userAvatarUrlKey);
      cachedAvatarUrl = null;
    }

    cachedFullName = data['fullName'];
    cachedEmail = data['email'];
    cachedIsLoggedIn = true;
    notifyUserChanged();

    // Merge guest cart items into user's account cart
    try {
      final guestItems = prefs.getStringList('guest_cart_course_ids') ?? [];
      final legacyItems = prefs.getStringList('cart_course_ids') ?? [];
      final userKey = 'cart_course_ids_user_${data['id']}';
      final userItems = prefs.getStringList(userKey) ?? [];

      final merged = <String>{...userItems, ...guestItems, ...legacyItems}.toList();
      await prefs.setStringList(userKey, merged);
      await prefs.remove('guest_cart_course_ids');
      await prefs.remove('cart_course_ids');
      await CartManager.updateCount();
    } catch (_) {}
  }

  // Retrieve token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Check if logged in
  Future<bool> isLoggedIn() async {
    if (cachedIsLoggedIn != null) return cachedIsLoggedIn!;
    final token = await getToken();
    cachedIsLoggedIn = token != null;
    return cachedIsLoggedIn!;
  }

  // Log out
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userFullNameKey);
    await prefs.remove(_userRolesKey);
    await prefs.remove(_userAvatarUrlKey);
    await prefs.remove('cart_course_ids');

    cachedFullName = null;
    cachedEmail = null;
    cachedAvatarUrl = null;
    cachedIsLoggedIn = false;
    notifyUserChanged();

    await CartManager.updateCount();
  }

  // Perform registration request
  Future<Map<String, dynamic>> register(
    String fullName,
    String email,
    String password,
    String role,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'fullName': fullName,
          'role': role,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Perform Google login request
  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveSession(data);

        // 🔥 PHÁT TÍN HIỆU NGẦM: Áp dụng tương tự cho đăng nhập Google
        if (onLoginSuccess != null) {
          onLoginSuccess!(data);
        }

        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Request password reset OTP
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': response.body};
      } else {
        return {'success': false, 'message': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Verify OTP code
  Future<Map<String, dynamic>> verifyOtp(String email, String otpCode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otpCode': otpCode}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': response.body};
      } else {
        return {'success': false, 'message': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Reset password to a new one
  Future<Map<String, dynamic>> resetPassword(
    String email,
    String newPassword,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'newPassword': newPassword}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': response.body};
      } else {
        return {'success': false, 'message': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Check if user is verified by calling /check-verification
  Future<bool> checkVerificationStatus(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/check-verification?email=$email'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['verified'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking verification status: $e');
      return false;
    }
  }

  // Resend verification email
  Future<Map<String, dynamic>> resendVerificationEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/resend-verification?email=$email'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': response.body};
      } else {
        return {'success': false, 'message': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get current user profile details
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No auth token found.'};
      }

      final url = baseUrl.replaceAll('/auth', '/v1/users/me');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Sync local cache
        final prefs = await SharedPreferences.getInstance();
        if (data['fullName'] != null) {
          await prefs.setString(_userFullNameKey, data['fullName']);
        }
        if (data['email'] != null) {
          await prefs.setString(_userEmailKey, data['email']);
        }
        if (data['avatarUrl'] != null) {
          await prefs.setString(_userAvatarUrlKey, data['avatarUrl']);
        } else {
          await prefs.remove(_userAvatarUrlKey);
        }
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Update current user profile details
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No auth token found.'};
      }

      final url = baseUrl.replaceAll('/auth', '/v1/users/me');
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final updatedData = jsonDecode(response.body);
        // Also update local SharedPreferences cache
        final prefs = await SharedPreferences.getInstance();
        if (updatedData['fullName'] != null) {
          await prefs.setString(_userFullNameKey, updatedData['fullName']);
        }
        if (updatedData['email'] != null) {
          await prefs.setString(_userEmailKey, updatedData['email']);
        }
        if (updatedData['avatarUrl'] != null) {
          await prefs.setString(_userAvatarUrlKey, updatedData['avatarUrl']);
        } else {
          await prefs.remove(_userAvatarUrlKey);
        }
        return {'success': true, 'data': updatedData};
      } else {
        return {'success': false, 'message': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Change password for logged-in user
  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No auth token found.'};
      }

      final url = baseUrl.replaceAll('/auth', '/v1/users/change-password');
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Password updated successfully!'};
      } else {
        try {
          final errBody = jsonDecode(response.body);
          return {'success': false, 'message': errBody['error'] ?? errBody['message'] ?? response.body};
        } catch (_) {
          return {'success': false, 'message': response.body};
        }
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Upload profile avatar
  Future<Map<String, dynamic>> uploadAvatar(PickedFile file) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No auth token found.'};
      }

      final url = baseUrl + '/profile/avatar';
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          file.bytes,
          filename: file.name,
        ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final updatedData = jsonDecode(responseBody);
        final prefs = await SharedPreferences.getInstance();
        if (updatedData['avatarUrl'] != null) {
          await prefs.setString(_userAvatarUrlKey, updatedData['avatarUrl']);
        }
        return {'success': true, 'data': updatedData};
      } else {
        try {
          final errBody = jsonDecode(responseBody);
          return {'success': false, 'message': errBody['error'] ?? errBody['message'] ?? responseBody};
        } catch (_) {
          return {'success': false, 'message': responseBody};
        }
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
