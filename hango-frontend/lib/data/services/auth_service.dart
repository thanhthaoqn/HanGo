import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Use localhost or 10.0.2.2 for Android emulator
  static const String baseUrl = 'http://localhost:8080/api/auth';
  
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userFullNameKey = 'user_fullname';
  static const String _userRolesKey = 'user_roles';

  // Perform login request
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveSession(data);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Save session details
  Future<void> saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, data['token']);
    await prefs.setInt(_userIdKey, data['id']);
    await prefs.setString(_userEmailKey, data['email']);
    await prefs.setString(_userFullNameKey, data['fullName']);
    await prefs.setStringList(_userRolesKey, List<String>.from(data['roles']));
  }

  // Retrieve token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Check if logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // Log out
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userFullNameKey);
    await prefs.remove(_userRolesKey);
  }
}
