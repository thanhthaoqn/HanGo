import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/config.dart';

class PaymentRepository {
  final String baseUrl = EnvConfig.v1BaseUrl;

  Future<Map<String, dynamic>> createPayment(int courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      throw Exception('Vui lòng đăng nhập để thanh toán.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/payment/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'courseId': courseId}),
    );

    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes);
      throw Exception('Tạo thanh toán thất bại: $body');
    }

    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> checkPaymentStatus(String txnRef) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      throw Exception('Chưa đăng nhập.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/payment/status/$txnRef'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 404) {
      return {'status': 'PENDING'};
    }

    if (response.statusCode != 200) {
      throw Exception('Lỗi kiểm tra trạng thái: ${response.statusCode}');
    }

    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}
