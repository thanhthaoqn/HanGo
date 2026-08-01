import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../../utils/config.dart';
import '../models/ticket_model.dart';

class TicketService {
  final _authService = AuthService();

  static String get baseUrl => EnvConfig.v1BaseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ""}',
    };
  }

  // 1. Create Ticket
  Future<Map<String, dynamic>> createTicket({
    required String title,
    required String description,
    String category = 'GENERAL_ENQUIRY',
    String priority = 'MEDIUM',
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/tickets');
      final body = jsonEncode({
        'title': title,
        'description': description,
        'category': category,
        'priority': priority,
      });

      final response = await http.post(uri, headers: headers, body: body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return {'success': true, 'ticket': TicketModel.fromJson(data)};
      } else {
        Map<String, dynamic> data = {};
        try {
          data = jsonDecode(response.body);
        } catch (_) {}
        return {'success': false, 'message': data['message'] ?? 'Failed to create ticket (${response.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 2. Update Ticket
  Future<Map<String, dynamic>> updateTicket(int ticketId, {String? title, String? description}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/tickets/$ticketId');
      final body = jsonEncode({
        if (title != null) 'title': title,
        if (description != null) 'description': description,
      });

      final response = await http.put(uri, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'ticket': TicketModel.fromJson(data)};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Failed to update ticket'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 3. Get My Tickets
  Future<Map<String, dynamic>> getMyTickets({String? status, int page = 0, int size = 10}) async {
    try {
      final headers = await _getHeaders();
      final statusParam = (status != null && status.isNotEmpty && status != 'ALL') ? '&status=$status' : '';
      final uri = Uri.parse('$baseUrl/tickets/my-tickets?page=$page&size=$size$statusParam');

      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<TicketModel> list = (data['content'] as List? ?? []).map((e) => TicketModel.fromJson(e)).toList();
        return {
          'success': true,
          'tickets': list,
          'totalElements': data['totalElements'] ?? 0,
          'totalPages': data['totalPages'] ?? 1,
        };
      } else {
        return {'success': false, 'tickets': <TicketModel>[]};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e', 'tickets': <TicketModel>[]};
    }
  }

  // 4. Get Ticket Detail
  Future<Map<String, dynamic>> getTicketDetail(int ticketId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/tickets/$ticketId');

      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'ticket': TicketModel.fromJson(data)};
      } else {
        return {'success': false, 'message': 'Ticket not found'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 5. Add Discussion Message
  Future<Map<String, dynamic>> addMessage(int ticketId, String message, {String? attachmentUrls}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/tickets/$ticketId/messages');
      final body = jsonEncode({
        'message': message,
        if (attachmentUrls != null) 'attachmentUrls': attachmentUrls,
      });

      final response = await http.post(uri, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'message': TicketMessageModel.fromJson(data)};
      } else {
        return {'success': false, 'message': 'Failed to send message'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 6. Management Tickets (Course Manager & Admin)
  Future<Map<String, dynamic>> getManagementTickets({String? status, String? category, String? keyword, int page = 0, int size = 10}) async {
    try {
      final headers = await _getHeaders();
      String query = 'page=$page&size=$size';
      if (status != null && status.isNotEmpty && status != 'ALL') query += '&status=$status';
      if (category != null && category.isNotEmpty && category != 'ALL') query += '&category=$category';
      if (keyword != null && keyword.isNotEmpty) query += '&keyword=${Uri.encodeComponent(keyword)}';

      final uri = Uri.parse('$baseUrl/management/tickets?$query');

      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<TicketModel> list = (data['content'] as List? ?? []).map((e) => TicketModel.fromJson(e)).toList();
        return {
          'success': true,
          'tickets': list,
          'totalElements': data['totalElements'] ?? 0,
          'totalPages': data['totalPages'] ?? 1,
        };
      } else {
        return {'success': false, 'tickets': <TicketModel>[]};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e', 'tickets': <TicketModel>[]};
    }
  }

  // 7. Process Ticket (Approve / Reject)
  Future<Map<String, dynamic>> processTicket(int ticketId, {required String action, String? rejectionReason, String? adminResponse}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/management/tickets/$ticketId/process');
      final body = jsonEncode({
        'action': action,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
        if (adminResponse != null) 'adminResponse': adminResponse,
      });

      final response = await http.post(uri, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'ticket': TicketModel.fromJson(data)};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Failed to process ticket'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
