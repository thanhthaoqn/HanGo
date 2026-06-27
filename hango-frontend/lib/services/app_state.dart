import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hango/domain/model/auth_session.dart';
import 'package:hango/services/secure_session_store.dart';

// 🚀 IMPORT các Model cần thiết cho AI Chatbox
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
  // 🔐 LOGIC QUẢN LÝ SESSION & ĐĂNG NHẬP
  // ==========================================

  Future<void> restoreSession() async {
    try {
      final savedSession = await _sessionStore.readSession();
      if (savedSession != null) {
        _session = savedSession;
        debugPrint(
          '[AppState] 🔄 Đã khôi phục Session thành công. Token: ${_session?.token}',
        );
      } else {
        debugPrint('[AppState] 📭 Không tìm thấy Session cũ.');
      }
    } catch (e) {
      debugPrint('[AppState] ❌ Lỗi khi khôi phục Session: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  void _handleExternalLoginSuccess(Map<String, dynamic> result) async {
    if (result['token'] == null) return;

    try {
      final roles = List<String>.from(result['roles'] ?? []);
      final isAdmin = roles.any((r) => r.contains('ADMIN'));
      final isTrainer = roles.any((r) => r.contains('TRAINER'));
      final primaryRole = isAdmin
          ? 'ADMIN'
          : (isTrainer ? 'TRAINER' : 'LEARNER');

      final nextSession = AuthSession(
        token: result['token'] ?? '',
        userId: result['id'] ?? 0,
        fullName: result['fullName'] ?? 'Learner',
        email: result['email'] ?? '',
        role: primaryRole,
      );

      await _acceptSession(nextSession);
      debugPrint('[AppState] ✅ Đăng nhập thành công! Token đã được lưu ngầm.');
    } catch (e) {
      debugPrint('[AppState] ❌ Lỗi khi tự động xử lý lưu session: $e');
    }
  }

  Future<void> _acceptSession(AuthSession nextSession) async {
    _session = nextSession;
    await _sessionStore.saveSession(nextSession);
    notifyListeners();
  }

  Future<void> logout() async {
    _session = null;
    await _sessionStore.clearSession();
    notifyListeners();
    debugPrint('[AppState] 🚪 Đã đăng xuất thành công.');
  }

  // ==========================================
  // 🤖 LOGIC AI CHATBOX
  // ==========================================

  /// 🛠️ Hàm tiện ích giúp chuẩn hóa URL Endpoint một cách tuyệt đối
  String _buildAiUrl(String path) {
    // 1. Loại bỏ đoạn '/auth' nếu có
    String base = AuthService.baseUrl.replaceAll('/auth', '');

    // 2. Xóa dấu gạch chéo thừa ở cuối của 'base' nếu có
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    // 3. Đảm bảo có tiền tố '/v1' trong hệ thống URL
    if (!base.contains('/v1')) {
      base = '$base/v1';
    }

    // 4. Đảm bảo 'path' truyền vào luôn bắt đầu bằng dấu '/'
    final String cleanPath = path.startsWith('/') ? path : '/$path';

    return '$base$cleanPath';
  }

  /// ✨ Kiểm tra trạng thái hoạt động của hệ thống AI (Gemini)
  Future<AiHealth> checkAiStatus() async {
    try {
      final String aiUrl = _buildAiUrl('/ai-assistant/status');
      debugPrint('[AppState] 🔍 Đang gọi API kiểm tra AI tại: $aiUrl');

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
          message: data['message'] ?? 'Gemini AI đang sẵn sàng',
          chatModel: data['chatModel'] ?? 'gemini-3.1-flash-lite',
          embeddingModel: data['embeddingModel'] ?? 'text-embedding-004',
        );
      }

      // Đọc thông báo lỗi thực tế từ Backend trả về nếu có thay vì tự gán cứng câu chữ
      String errMsg = 'Dịch vụ AI bảo trì';
      try {
        final errData = jsonDecode(response.body);
        errMsg = errData['message'] ?? errData['error'] ?? errMsg;
      } catch (_) {}

      return AiHealth(
        available: false,
        message: '$errMsg (Mã: ${response.statusCode})',
        chatModel: 'N/A',
        embeddingModel: 'N/A',
      );
    } catch (e) {
      debugPrint('[AppState] ❌ Lỗi kiểm tra AI status: $e');
      return AiHealth(
        available: false,
        message: 'Mất kết nối tới Server Backend hệ thống.',
        chatModel: 'N/A',
        embeddingModel: 'N/A',
      );
    }
  }

  /// ✨ Gửi tin nhắn câu hỏi bài học lên AI Server
  Future<AiChatResponse> sendAiMessage({
    required int lessonId,
    required int? conversationId,
    required String message,
  }) async {
    try {
      final String finalChatUrl = _buildAiUrl('/ai-assistant/messages');
      debugPrint('[AppState] 💬 Gửi tin nhắn đến: $finalChatUrl');

      final response = await http
          .post(
            Uri.parse(finalChatUrl),
            headers: {
              'Content-Type': 'application/json',
              if (_session?.token != null)
                'Authorization': 'Bearer ${_session!.token}',
            },
            body: jsonEncode({
              'lessonId': lessonId,
              if (conversationId != null) 'conversationId': conversationId,
              'message': message,
            }),
          )
          .timeout(
            const Duration(seconds: 30),
          ); // Tăng timeout cho AI kịp sinh chuỗi text

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AiChatResponse(
          conversationId: data['conversationId'] ?? conversationId ?? 1,
          reply:
              data['reply'] ??
              data['message'] ??
              'Không nhận được câu trả lời từ AI.',
          wasOutOfScope: data['wasOutOfScope'] ?? false,
        );
      } else {
        String serverError = 'Lỗi hệ thống xử lý AI';
        try {
          final errBody = jsonDecode(response.body);
          serverError = errBody['message'] ?? errBody['error'] ?? serverError;
        } catch (_) {}
        throw Exception('$serverError (Mã: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('[AppState] ❌ Lỗi kết nối gửi tin nhắn AI: $e');
      // Thôi giả lập câu trả lời fake, ném chuỗi lỗi trực quan để hiển thị lên UI Chatbox cho dễ debug
      return AiChatResponse(
        conversationId: conversationId ?? 0,
        reply: '⚠️ Lỗi: ${e.toString().replaceAll('Exception:', '')}',
        wasOutOfScope: false,
      );
    }
  }
}

class AiChatResponse {
  final int conversationId;
  final String reply;
  final bool wasOutOfScope;

  AiChatResponse({
    required this.conversationId,
    required this.reply,
    required this.wasOutOfScope,
  });
}
