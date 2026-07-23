import 'package:flutter/foundation.dart';

class EnvConfig {
  static String get apiBaseUrl {
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.contains('hangog92.online')) {
        return 'https://api.hangog92.online';
      }
      return 'http://localhost:8080';
    } else {
      // Mobile / Emulator fallback
      return 'http://10.0.2.2:8080';
    }
  }

  static String get v1BaseUrl => '$apiBaseUrl/api/v1';
  static String get authBaseUrl => '$apiBaseUrl/api/auth';
}
