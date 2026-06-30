import 'package:dio/dio.dart';
import '../../domain/model/trainer_task_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrainerTaskRepository {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8080/api/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

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

      final queryParams = <String, dynamic>{
        'page': page,
        'size': size,
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

      final response = await _dio.get(
        '/trainer/tasks',
        queryParameters: queryParams,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
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

  Future<void> acceptTask(int id) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await _dio.put(
        '/trainer/tasks/$id/accept',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to accept task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error accepting task: $e');
    }
  }
}
