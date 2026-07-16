import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartManager {
  static final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);

  static Future<void> updateCount() async {
    final prefs = await SharedPreferences.getInstance();
    final cart = prefs.getStringList('cart_course_ids') ?? [];
    cartCountNotifier.value = cart.length;
  }
}
