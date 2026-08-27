import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hango/domain/model/auth_session.dart';
import 'package:hango/services/secure_session_store.dart';

// IMPORT các Model cần thiết cho AI Chatbox
import 'package:hango/domain/model/ai_health.dart';
import 'package:hango/domain/model/ai_models.dart';
import '../../data/services/auth_service.dart';

class AppState extends ChangeNotifier {
  final SecureSessionStore _sessionStore = SecureSessionStore();

  AuthSession? _session;
  bool _isInitialized = false;

  AuthSession? get session => _session;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _session != null;
  bool get isBooting => !_isInitialized;

  AppState() {
    // Đăng ký lắng nghe sự kiện đăng nhập thành công từ AuthService
    AuthService.onLoginSuccess = (result) {
      _handleExternalLoginSuccess(result);
    };

    // Tự động nạp lại session cũ khi mở app
    restoreSession();
  }

  // ==========================================
  // LOGIC QUẢN LÝ SESSION & ĐĂNG NHẬP
  // ==========================================

  Future<void> restoreSession() async {
    try {
      // Read from AuthService's SharedPreferences-backed store (the same one
      // every real API call reads its token from) rather than SecureSessionStore,
      // so AppState can never restore a "successful" session that the rest of
      // the app's API calls disagree with (e.g. after AuthService.logout()
      // clears SharedPreferences but SecureSessionStore was never told).
      final savedSession = await AuthService().getStoredSession();
      if (savedSession != null) {
        _session = savedSession;
        debugPrint(
          '[AppState] Session restores completed. Token: ${_session?.token}',
        );
      } else {
        debugPrint('[AppState] No session found.');
      }
    } catch (e) {
      debugPrint('[AppState] Error restoring Session: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  void _handleExternalLoginSuccess(Map<String, dynamic> result) async {
    if (result['token'] == null) return;

    try {
      final roles = List<String>.from(result['roles'] ?? []);
      final isAdmin = roles.any((r) => r.toUpperCase().contains('ADMIN'));
      final isTrainerLead = roles.any(
        (r) => r.toUpperCase().contains('COURSE_MANAGER'),
      );
      final isCourseManager = roles.any(
        (r) => r.toUpperCase().contains('COURSE_MANAGER'),
      );
      final isTrainer =
          roles.any((r) => r.toUpperCase().contains('TRAINER')) &&
          !isTrainerLead &&
          !isCourseManager;
      final primaryRole = isAdmin
          ? 'ADMIN'
          : (isCourseManager
                ? 'COURSE_MANAGER'
                : (isTrainerLead
                      ? 'COURSE_MANAGER'
                      : (isTrainer ? 'TRAINER' : 'LEARNER')));

      final nextSession = AuthSession(
        token: result['token'] ?? '',
        userId: result['id'] ?? 0,
        fullName: result['fullName'] ?? 'Learner',
        email: result['email'] ?? '',
        role: primaryRole,
      );

      await _acceptSession(nextSession);
      debugPrint('[AppState] Login successful! Token has been saved.');
    } catch (e) {
      debugPrint('[AppState] Error automatically handling session save: $e');
    }
  }

  Future<void> _acceptSession(AuthSession nextSession) async {
    // AuthService.login() already persisted this session to SharedPreferences
    // (awaited, before firing onLoginSuccess) — nothing left to persist here,
    // just reflect it in memory so isAuthenticated/session update immediately.
    _session = nextSession;
    notifyListeners();
  }

  Future<void> logout() async {
    _session = null;
    await _sessionStore.clearSession();
    notifyListeners();
    debugPrint('[AppState] Logged out successfully.');
  }

  // ==========================================
  // LOGIC AI CHATBOX
  // ==========================================

  /// Utility function to build absolute URL endpoints
  String _buildAiUrl(String path) {
    // 1. Remove '/auth' segment if present
    String base = AuthService.baseUrl.replaceAll('/auth', '');

    // 2. Remove trailing slash from 'base' if present
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    // 3. Ensure '/v1' prefix is included in the URL system
    if (!base.contains('/v1')) {
      base = '$base/v1';
    }

    // 4. Ensure the given 'path' always starts with a '/'
    final String cleanPath = path.startsWith('/') ? path : '/$path';

    return '$base$cleanPath';
  }

  /// Checks the operational status of the AI system (Gemini)
  Future<AiHealth> checkAiStatus() async {
    try {
      final String aiUrl = _buildAiUrl('/ai-assistant/status');
      debugPrint('[AppState] Calling AI check API at: $aiUrl');

      final response = await http
          .get(
            Uri.parse(aiUrl),
            headers: {
              'Content-Type': 'application/json',
              if (_session?.token != null)
                'Authorization': 'Bearer ${_session!.token}',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AiHealth(
          available: data['available'] ?? true,
          message: data['message'] ?? 'Online',
          chatModel: data['chatModel'] ?? 'gemini-3.1-flash-lite',
          embeddingModel: data['embeddingModel'] ?? 'text-embedding-004',
        );
      }

      // Read the actual error message from the Backend if available instead of hardcoding
      String errMsg = 'AI Service is unavailable';
      try {
        final errData = jsonDecode(response.body);
        errMsg = errData['message'] ?? errData['error'] ?? errMsg;
      } catch (_) {}

      return AiHealth(
        available: false,
        message: '$errMsg (Status code: ${response.statusCode})',
        chatModel: 'N/A',
        embeddingModel: 'N/A',
      );
    } catch (e) {
      debugPrint('[AppState] Error checking AI status: $e');
      return AiHealth(
        available: false,
        message: 'Failed to connect to the Backend Server.',
        chatModel: 'N/A',
        embeddingModel: 'N/A',
      );
    }
  }

  /// Sends a lesson question message to the AI Server
  Future<AiChatResponse> sendAiMessage({
    required int lessonId,
    required int? conversationId,
    required String message,
  }) async {
    try {
      final String finalChatUrl = _buildAiUrl('/ai-assistant/messages');
      debugPrint('[AppState] Sending message to: $finalChatUrl');

      // Gui POST kem JWT tu session; body chua lessonId + conversationId + message
      final response = await http
          .post(
            Uri.parse(finalChatUrl), // Đường dẫn: /api/v1/ai-assistant/messages
            headers: {
              'Content-Type': 'application/json',
              if (_session?.token != null)
                'Authorization':
                    'Bearer ${_session!.token}', // Đính kèm vé bảo mật
            },
            body: jsonEncode({
              'lessonId': lessonId,
              if (conversationId != null) 'conversationId': conversationId,
              'message': message,
            }), // Gói JSON chứa lessonId và message
          )
          .timeout(
            const Duration(seconds: 30),
          ); // Increase timeout to allow AI enough time to generate the text response

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AiChatResponse(
          conversationId: data['conversationId'] ?? conversationId ?? 1,
          reply: data['reply'] ?? data['message'] ?? 'No response from AI.',
          wasOutOfScope: data['wasOutOfScope'] ?? false,
          suggestedQuestions:
              (data['suggestedQuestions'] as List?)
                  ?.whereType<String>()
                  .where((e) => e.trim().isNotEmpty)
                  .toList() ??
              const [],
        );
      } else {
        String serverError = 'Error system AI';
        try {
          final errBody = jsonDecode(response.body);
          serverError = errBody['message'] ?? errBody['error'] ?? serverError;
        } catch (_) {}
        throw Exception('$serverError (Status code: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('[AppState] Error connecting to AI: $e');
      // Simulate a fake AI response containing the error message directly on the UI Chatbox for easier debugging
      return AiChatResponse(
        conversationId: conversationId ?? 0,
        reply: ' Error: ${e.toString().replaceAll('Exception:', '')}',
        wasOutOfScope: false,
        suggestedQuestions: const [],
      );
    }
  }
}

class AiChatResponse {
  final int conversationId;
  final String reply;
  final bool wasOutOfScope;
  final List<String> suggestedQuestions;

  AiChatResponse({
    required this.conversationId,
    required this.reply,
    required this.wasOutOfScope,
    this.suggestedQuestions = const [],
  });
}
