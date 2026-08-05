import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../utils/file_picker_helper.dart';

import '../../utils/config.dart';
import '../../utils/cart_manager.dart';
import '../../utils/web_session_helper.dart';
import '../../domain/model/auth_session.dart';

class AuthService {
  // 🚀 DÒNG THÊM MỚI: Cổng phát tín hiệu (Callback static) để AppState đứng từ xa lắng nghe
  static Function(Map<String, dynamic>)? onLoginSuccess;

  // Use dynamic baseUrl configuration
  static String get baseUrl => EnvConfig.authBaseUrl;

  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userFullNameKey = 'user_fullname';
  static const String _userRolesKey = 'user_roles';
  static const String _userAvatarUrlKey = 'user_avatar_url';

  // The http call itself failed (no response at all) — e.g. CORS rejection,
  // backend not running/unreachable, DNS failure, timeout. Always log the
  // real exception so it's visible while debugging; only show the raw text
  // to the user in debug builds, since in release it's not actionable for them.
  static String _networkErrorMessage(Object error) {
    debugPrint('[AuthService] Network error: $error');
    if (kDebugMode) {
      return 'Network error: $error';
    }
    return 'Could not reach the server. Please check your connection and try again.';
  }

  // Turn a raw HTTP error response body into a short, user-facing message.
  // Backend errors normally arrive as JSON (`{"message": "..."}`), but a few
  // paths still fall back to a plain "Error: ..." string or, in the worst
  // case, an HTML/stack-trace body — this makes sure the caller never shows
  // that raw payload directly in a toast.
  static String _extractErrorMessage(String body) {
    const fallback = 'Something went wrong. Please try again.';
    if (body.trim().isEmpty) return fallback;

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final msg = decoded['message'] ?? decoded['error'];
        if (msg is String && msg.trim().isNotEmpty) return msg;
      }
    } catch (_) {
      // Not JSON, fall through.
    }

    String text = body.trim();
    if (text.startsWith('Error: ')) {
      text = text.substring(7).trim();
    }
    if (text.isEmpty) return fallback;
    // Guard against dumping an HTML error page / stack trace into the UI.
    if (text.length > 200 || text.startsWith('<')) return fallback;
    return text;
  }

  // Perform login request
  Future<Map<String, dynamic>> login(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setRememberMe(rememberMe);
        await saveSession(data);

        // 🔥 PHÁT TÍN HIỆU NGẦM: Báo cho AppState biết để cập nhật UI ngay lập tức
        if (onLoginSuccess != null) {
          onLoginSuccess!(data);
        }

        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': _extractErrorMessage(response.body)};
      }
    } catch (e) {
      return {'success': false, 'message': _networkErrorMessage(e)};
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
    if (data['refreshToken'] != null) {
      await prefs.setString(_refreshTokenKey, data['refreshToken']);
    }
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

  // Rebuild an AuthSession from the same SharedPreferences-backed store every
  // actual API call reads its token from (see getToken()/CourseManagerApi/etc.),
  // so callers like AppState never restore a session that this store disagrees
  // with. Mirrors the role-priority logic AppState._handleExternalLoginSuccess
  // uses right after a fresh login.
  Future<AuthSession?> getStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) return null;

    final roles = prefs.getStringList(_userRolesKey) ?? [];
    final isAdmin = roles.any((r) => r.toUpperCase().contains('ADMIN'));
    final isCourseManager = roles.any((r) => r.toUpperCase().contains('COURSE_MANAGER'));
    final isTrainer = roles.any((r) => r.toUpperCase().contains('TRAINER')) && !isCourseManager;
    final primaryRole = isAdmin
        ? 'ADMIN'
        : (isCourseManager ? 'COURSE_MANAGER' : (isTrainer ? 'TRAINER' : 'LEARNER'));

    return AuthSession(
      token: token,
      userId: prefs.getInt(_userIdKey) ?? 0,
      fullName: prefs.getString(_userFullNameKey) ?? 'Learner',
      email: prefs.getString(_userEmailKey) ?? '',
      role: primaryRole,
    );
  }

  // Retrieve refresh token
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  // Exchange the stored refresh token for a new access token (and a rotated
  // refresh token). Returns false (and leaves the session as-is) on failure;
  // callers should treat that as "session is no longer valid".
  Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, data['token']);
        await prefs.setString(_refreshTokenKey, data['refreshToken']);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
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
    // Best-effort: revoke the refresh token server-side so it can't be reused.
    // Still clears local session below even if this call fails (e.g. offline).
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken != null) {
        await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        );
      }
    } catch (_) {}

    setRememberMe(false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
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

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: kIsWeb ? null : '471566696084-ugjjgk7vdtplhbgqkd1g1hi9piltd0ol.apps.googleusercontent.com',
        clientId: '471566696084-ugjjgk7vdtplhbgqkd1g1hi9piltd0ol.apps.googleusercontent.com',
      );
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.disconnect();
      }
    } catch (e) {
      debugPrint('Error disconnecting Google Sign In: $e');
    }

    await CartManager.updateCount();
  }

  // Perform registration request
  Future<Map<String, dynamic>> register(
    String fullName,
    String email,
    String password,
    String role, {
    String? confirmPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'confirmPassword': confirmPassword ?? password,
          'fullName': fullName,
          'role': role,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': _extractErrorMessage(response.body)};
      }
    } catch (e) {
      return {'success': false, 'message': _networkErrorMessage(e)};
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
        return {'success': false, 'message': _extractErrorMessage(response.body)};
      }
    } catch (e) {
      return {'success': false, 'message': _networkErrorMessage(e)};
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
        return {'success': false, 'message': _extractErrorMessage(response.body)};
      }
    } catch (e) {
      return {'success': false, 'message': _networkErrorMessage(e)};
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
        return {'success': false, 'message': _extractErrorMessage(response.body)};
      }
    } catch (e) {
      return {'success': false, 'message': _networkErrorMessage(e)};
    }
  }

  // Reset password to a new one
  Future<Map<String, dynamic>> resetPassword(
    String email,
    String otpCode,
    String newPassword,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otpCode': otpCode, 'newPassword': newPassword}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': response.body};
      } else {
        return {'success': false, 'message': _extractErrorMessage(response.body)};
      }
    } catch (e) {
      return {'success': false, 'message': _networkErrorMessage(e)};
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
        return {'success': false, 'message': _extractErrorMessage(response.body)};
      }
    } catch (e) {
      return {'success': false, 'message': _networkErrorMessage(e)};
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
        return {'success': false, 'message': _extractErrorMessage(response.body)};
      }
    } catch (e) {
      return {'success': false, 'message': _networkErrorMessage(e)};
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
        return {'success': false, 'message': _extractErrorMessage(response.body)};
      }
    } catch (e) {
      return {'success': false, 'message': _networkErrorMessage(e)};
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
        return {'success': false, 'message': _extractErrorMessage(response.body)};
      }
    } catch (e) {
      return {'success': false, 'message': _networkErrorMessage(e)};
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
        return {'success': false, 'message': _extractErrorMessage(responseBody)};
      }
    } catch (e) {
      return {'success': false, 'message': _networkErrorMessage(e)};
    }
  }
}
