import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/config.dart';

class RevenueSettlementService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? prefs.getString('jwt_token');
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

  Future<bool> settleStatement(int statementId, {String? bankTxnRef, String? notes, String? payoutReceiptUrl}) async {
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
          'payoutReceiptUrl': payoutReceiptUrl ?? '',
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error settling statement: $e');
    }
    return false;
  }

  Future<bool> regenerateStatement(int statementId) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${EnvConfig.v1BaseUrl}/course-manager/statements/$statementId/regenerate'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error regenerating statement: $e');
    }
    return false;
  }

  Future<bool> rejectStatement(int statementId, String reason) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${EnvConfig.v1BaseUrl}/trainer/statements/$statementId/reject'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'reason': reason,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error rejecting statement: $e');
    }
    return false;
  }

  Future<bool> cancelStatement(int statementId) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${EnvConfig.v1BaseUrl}/course-manager/statements/$statementId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error cancelling statement: $e');
    }
    return false;
  }

  Future<List<dynamic>> getStatementPayments(int statementId) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${EnvConfig.v1BaseUrl}/course-manager/statements/$statementId/items'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting statement payments: $e');
    }
    return [];
  }


  Future<Map<String, dynamic>?> getAllPayments({
    int page = 0,
    int size = 20,
    String? status,
    String? settlementStatus,
    String? search,
  }) async {
    try {
      final token = await _getToken();
      final queryParams = <String, String>{
        'page': page.toString(),
        'size': size.toString(),
      };
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (settlementStatus != null && settlementStatus.isNotEmpty) queryParams['settlementStatus'] = settlementStatus;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('${EnvConfig.v1BaseUrl}/payment/manager/all').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting all payments for manager: $e');
    }
    return null;
  }

  Future<List<int>?> exportStatementsExcel({String? periodMonth, String? status}) async {
    try {
      final token = await _getToken();
      final queryParams = <String, String>{};
      if (periodMonth != null && periodMonth.isNotEmpty) queryParams['periodMonth'] = periodMonth;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final uri = Uri.parse('${EnvConfig.v1BaseUrl}/course-manager/statements/export-excel')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('Error exporting statements excel: $e');
    }
    return null;
  }

  Future<List<int>?> exportPaymentsExcel({
    String? status,
    String? settlementStatus,
    String? search,
  }) async {
    try {
      final token = await _getToken();
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (settlementStatus != null && settlementStatus.isNotEmpty) queryParams['settlementStatus'] = settlementStatus;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('${EnvConfig.v1BaseUrl}/payment/manager/export-excel')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        debugPrint('exportPaymentsExcel failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error exporting payments excel: $e');
    }
    return null;
  }
}

