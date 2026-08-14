import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/config.dart';

class PaymentRepository {
  final String baseUrl = EnvConfig.v1BaseUrl;

  Future<Map<String, dynamic>> createPayment({int? courseId, List<int>? courseIds}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      throw Exception('Please log in to check out.');
    }

    final Map<String, dynamic> bodyData = {};
    if (courseIds != null && courseIds.isNotEmpty) {
      bodyData['courseIds'] = courseIds;
    } else if (courseId != null) {
      bodyData['courseId'] = courseId;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/payment/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(bodyData),
    );

    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes);
      try {
        final errorMap = jsonDecode(body) as Map<String, dynamic>;
        if (errorMap.containsKey('error')) {
          throw Exception(errorMap['error']);
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) {
          rethrow;
        }
      }
      throw Exception('Failed to create payment: $body');
    }

    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> checkPaymentStatus(String txnRef) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      throw Exception('Not logged in.');
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
      throw Exception('Failed to check payment status: ${response.statusCode}');
    }

    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<dynamic> getMyPaymentHistory({int page = 0, int size = 10, String status = 'ALL'}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      throw Exception('Please log in.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/payment/my-history?page=$page&size=$size&status=$status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes);
      throw Exception('Failed to load payment history: $body');
    }

    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
