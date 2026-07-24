import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/config.dart';

class RevenueSettlementService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // --- Trainer APIs ---

  Future<Map<String, dynamic>?> getTrainerRevenueSummary() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${EnvConfig.v1BaseUrl}/trainer/revenue-summary'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
      debugPrint('getTrainerRevenueSummary failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error getting trainer revenue summary: $e');
    }
    return null;
  }

  Future<List<dynamic>> getTrainerStatements() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${EnvConfig.v1BaseUrl}/trainer/statements'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting trainer statements: $e');
    }
    return [];
  }

  Future<bool> confirmTrainerStatement(int statementId) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${EnvConfig.v1BaseUrl}/trainer/statements/$statementId/confirm'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error confirming trainer statement: $e');
    }
    return false;
  }

  // --- Course Manager / Admin APIs ---

  Future<List<dynamic>> getCourseManagerStatements({String? periodMonth, String? status}) async {
    try {
      final token = await _getToken();
      final queryParams = <String, String>{};
      if (periodMonth != null && periodMonth.isNotEmpty) queryParams['periodMonth'] = periodMonth;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final uri = Uri.parse('${EnvConfig.v1BaseUrl}/course-manager/statements').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting course manager statements: $e');
    }
    return [];
  }

  Future<List<dynamic>> generateMonthlyCutoff({String? periodMonth}) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('${EnvConfig.v1BaseUrl}/course-manager/statements/generate').replace(
        queryParameters: periodMonth != null && periodMonth.isNotEmpty ? {'periodMonth': periodMonth} : null,
      );

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error generating monthly cutoff: $e');
    }
    return [];
  }

  Future<bool> settleStatement(int statementId, {String? bankTxnRef, String? notes}) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${EnvConfig.v1BaseUrl}/course-manager/statements/$statementId/settle'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'bankTxnRef': bankTxnRef ?? '',
          'notes': notes ?? '',
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error settling statement: $e');
    }
    return false;
  }
}
