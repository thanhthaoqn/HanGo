import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/model/trainer_task_model.dart';
import '../../domain/model/task_activity_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrainerTaskRepository {
  final String _baseUrl = 'http://localhost:8080/api/v1';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, dynamic>> getTrainerTasks({
    DateTime? fromDate,
    DateTime? toDate,
    String? type,
    String? search,
    int page = 0,
    int size = 10,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final queryParams = <String, String>{
        'page': page.toString(),
        'size': size.toString(),
      };

      if (fromDate != null) {
        queryParams['fromDate'] = fromDate.toIso8601String();
      }
      if (toDate != null) {
        queryParams['toDate'] = toDate.toIso8601String();
      }
      if (type != null && type != 'All type') {
        queryParams['type'] = type;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse('$_baseUrl/trainer/tasks').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<TrainerTaskModel> tasks = (data['content'] as List)
            .map((json) => TrainerTaskModel.fromJson(json))
            .toList();

        return {
          'tasks': tasks,
          'totalPages': data['totalPages'],
          'totalElements': data['totalElements'],
        };
      } else {
        throw Exception('Failed to fetch trainer tasks: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching trainer tasks: $e');
    }
  }

  Future<Map<String, dynamic>> getTaskDetail(int id) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final uri = Uri.parse('$_baseUrl/trainer/tasks/$id');

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch task detail: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching task detail: $e');
    }
  }

  Future<List<TaskActivityModel>> getTaskActivities(int id) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final uri = Uri.parse('$_baseUrl/trainer/tasks/$id/activities');

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => TaskActivityModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch task activities: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching task activities: $e');
    }
  }

  Future<void> acceptTask(int id) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final uri = Uri.parse('$_baseUrl/trainer/tasks/$id/accept');

      final response = await http.put(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to accept task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error accepting task: $e');
    }
  }
}
