import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/model/trainer_lead_dashboard_stats_model.dart';
import 'package:hango/domain/model/task_activity_model.dart';

class TrainerLeadRepository {
  final String baseUrl = 'http://localhost:8080/api/v1';

  Future<TrainerLeadDashboardStatsModel> getDashboardStats() async {
    try {
      final uri = Uri.parse('$baseUrl/trainer-lead/dashboard/stats');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return TrainerLeadDashboardStatsModel.fromJson(data);
      } else {
        throw Exception('Failed to load dashboard stats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching dashboard stats: $e');
    }
  }

  Future<Map<String, dynamic>> getTasks({
    DateTime? from,
    DateTime? to,
    String? type,
    String? search,
    int page = 0,
    int size = 10,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'size': size.toString(),
      };
      
      if (from != null) queryParams['fromDate'] = from.toIso8601String();
      if (to != null) queryParams['toDate'] = to.toIso8601String();
      if (type != null && type != 'All type') queryParams['type'] = type;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/trainer-lead/tasks').replace(queryParameters: queryParams);
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data; // Spring Page object
      } else {
        throw Exception('Failed to load tasks: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching tasks: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTrainers() async {
    try {
      final uri = Uri.parse('$baseUrl/trainer-lead/tasks/trainers');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load trainers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching trainers: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getReviewers() async {
    try {
      final uri = Uri.parse('$baseUrl/trainer-lead/tasks/reviewers');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load reviewers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching reviewers: $e');
    }
  }

  Future<void> createTask(Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('$baseUrl/trainer-lead/tasks');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating task: $e');
    }
  }

  Future<Map<String, dynamic>> getTaskDetail(int id) async {
    try {
      final uri = Uri.parse('$baseUrl/trainer-lead/tasks/$id');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data;
      } else {
        throw Exception('Failed to load task details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching task details: $e');
    }
  }

  Future<void> updateTask(int id, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('$baseUrl/trainer-lead/tasks/$id');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating task: $e');
    }
  }

  Future<void> updateTaskStatus(int id, String status) async {
    try {
      final uri = Uri.parse('$baseUrl/trainer-lead/tasks/$id/status');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({'status': status}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update task status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating task status: $e');
    }
  }

  Future<List<TaskActivityModel>> getTaskActivities(int id) async {
    try {
      final uri = Uri.parse('$baseUrl/trainer-lead/tasks/$id/activities');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => TaskActivityModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load task activities');
      }
    } catch (e) {
      throw Exception('Error fetching task activities: $e');
    }
  }
}

