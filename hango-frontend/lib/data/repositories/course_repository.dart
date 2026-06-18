import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/model/course.dart';

class CourseRepository {
  // Use localhost for Web/Desktop. For Android Emulator, change to 10.0.2.2
  final String baseUrl = 'http://localhost:8080/api/v1';

  Future<List<Course>> fetchCourses({
    String search = '',
    String filterType = 'ALL',
    String difficulty = 'ALL',
  }) async {
    try {
      final queryParams = <String, String>{};
      if (search.isNotEmpty) queryParams['search'] = search;
      if (filterType != 'ALL') queryParams['filterType'] = filterType;
      if (difficulty != 'ALL') queryParams['difficulty'] = difficulty;

      final uri = Uri.parse('$baseUrl/courses').replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((json) => Course.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load courses: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching courses: $e');
    }
  }
}
