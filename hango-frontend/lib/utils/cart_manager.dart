import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/course_repository.dart';

class CartManager {
  static final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);

  static Future<void> updateCount() async {
    final prefs = await SharedPreferences.getInstance();
    var cart = prefs.getStringList('cart_course_ids') ?? [];
    
    final token = prefs.getString('auth_token');
    if (token != null) {
      try {
        final repo = CourseRepository();
        final inProgress = await repo.fetchCourses(filterType: 'IN_PROGRESS');
        final completed = await repo.fetchCourses(filterType: 'COMPLETED');
        
        final enrolledIds = <String>{};
        for (final c in inProgress) {
          enrolledIds.add(c.id.toString());
          await prefs.setBool('enrolled_course_id_${c.id}', true);
        }
        for (final c in completed) {
          enrolledIds.add(c.id.toString());
          await prefs.setBool('enrolled_course_id_${c.id}', true);
        }
        
        final originalLength = cart.length;
        cart = cart.where((id) => !enrolledIds.contains(id)).toList();
        if (cart.length != originalLength) {
          await prefs.setStringList('cart_course_ids', cart);
        }
      } catch (e) {
        debugPrint('Error syncing cart with database: $e');
      }
    }
    
    cartCountNotifier.value = cart.length;
  }
}
