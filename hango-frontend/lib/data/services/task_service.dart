import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';

class TaskService {
  final Dio _dio = Dio();
  final String baseUrl = 'http://localhost:8080/api/v1/tasks';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, dynamic>> getTasks({
    int page = 0,
    int size = 10,
    int? leadId,
    int? creatorId,
    String? search,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final token = await _getToken();

      final Map<String, dynamic> queryParams = {'page': page, 'size': size};

      if (leadId != null) queryParams['leadId'] = leadId;
      if (creatorId != null) queryParams['creatorId'] = creatorId;
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (fromDate != null && fromDate.isNotEmpty) {
        queryParams['fromDate'] = fromDate;
      }
      if (toDate != null && toDate.isNotEmpty) {
        queryParams['toDate'] = toDate;
      }

      final response = await _dio.get(
        baseUrl,
        queryParameters: queryParams,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> content = response.data['content'] ?? [];
        final tasks = content.map((json) => TaskModel.fromJson(json)).toList();
        return {
          'success': true,
          'tasks': tasks,
          'totalPages': response.data['totalPages'] ?? 1,
          'totalElements': response.data['totalElements'] ?? 0,
        };
      }
      return {'success': false, 'message': 'Failed to load tasks'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getTrainers() async {
    try {
      final token = await _getToken();
      final response = await _dio.get(
        'http://localhost:8080/api/v1/trainer-lead/trainers',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'trainers': response.data};
      }
      return {'success': false, 'message': 'Failed to load trainers'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> data) async {
    try {
      final token = await _getToken();
      final response = await _dio.post(
        baseUrl,
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      }
      return {'success': false, 'message': 'Failed to create task'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?.toString() ?? e.toString(),
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateTaskStatus(
    int taskId,
    String status,
    {int? creatorId, String? submissionNotes, String? reviewComment}
  ) async {
    try {
      final token = await _getToken();
      
      Map<String, dynamic> data = {'status': status};
      if (creatorId != null) data['creatorId'] = creatorId;
      if (submissionNotes != null) data['submissionNotes'] = submissionNotes;
      if (reviewComment != null) data['reviewComment'] = reviewComment;

      final response = await _dio.put(
        '$baseUrl/$taskId/status',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      }
      return {'success': false, 'message': 'Failed to update task status'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?.toString() ?? e.toString(),
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteTask(int taskId) async {
    try {
      final token = await _getToken();
      final response = await _dio.delete(
        '$baseUrl/$taskId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Failed to delete task'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?.toString() ?? e.toString(),
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
