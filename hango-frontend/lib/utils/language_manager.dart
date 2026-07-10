import 'package:flutter/foundation.dart';

class LanguageManager {
  static final ValueNotifier<bool> isVietnamese = ValueNotifier<bool>(true);

  static bool get isVi => isVietnamese.value;

  static void setLanguage(bool isVi) {
    isVietnamese.value = isVi;
  }
}
