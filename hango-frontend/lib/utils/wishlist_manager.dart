import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WishlistManager {
  static final ValueNotifier<int> wishlistCountNotifier = ValueNotifier<int>(0);

  static Future<void> updateCount() async {
    final prefs = await SharedPreferences.getInstance();
    final wishlist = prefs.getStringList('wishlisted_course_ids') ?? [];
    wishlistCountNotifier.value = wishlist.length;
  }
}
