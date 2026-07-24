import 'package:flutter/foundation.dart';

class LanguageManager {
  static final ValueNotifier<bool> isVietnamese = ValueNotifier<bool>(false);

  static bool get isVi => false;

  static void setLanguage(bool isVi) {
    isVietnamese.value = false;
  }
}
