import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../utils/config.dart';

class PublicStatsService {
  static int coursesCount = 0;
  static int learnersCount = 0;
  static int freeExamsCount = 0;
  static bool isLoaded = false;
  static Future<void>? _pendingFetch;

  static Future<void> fetch({bool force = false}) async {
    if (isLoaded && !force) return;
    if (_pendingFetch != null) return _pendingFetch;

    _pendingFetch = () async {
      try {
        final response = await http.get(
          Uri.parse('${EnvConfig.v1BaseUrl}/metadata/public-stats'),
        );
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
          coursesCount = (data['coursesCount'] ?? 0) as int;
          learnersCount = (data['learnersCount'] ?? 0) as int;
          freeExamsCount = (data['freeExamsCount'] ?? 0) as int;
          isLoaded = true;
        }
      } catch (_) {} finally {
        _pendingFetch = null;
      }
    }();

    return _pendingFetch;
  }
}
