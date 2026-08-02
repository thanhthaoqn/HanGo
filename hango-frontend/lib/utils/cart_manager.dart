import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/cart_repository.dart';
import '../data/repositories/course_repository.dart';
import '../domain/model/course.dart';

class CartManager {
  static final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<List<Course>> cartCoursesNotifier = ValueNotifier<List<Course>>([]);
  static final CartRepository _cartRepository = CartRepository();
  static final CourseRepository _courseRepository = CourseRepository();

  static final Set<int> _pendingDeletedCourseIds = <int>{};

  static bool isPendingDeletion(int courseId) {
    return _pendingDeletedCourseIds.contains(courseId);
  }

  static Future<String> getCartKey() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userId = prefs.getInt('user_id');
    if (token != null && token.isNotEmpty && userId != null) {
      return 'cart_course_ids_user_$userId';
    } else {
      return 'guest_cart_course_ids';
    }
  }

  static Future<List<String>> getCartIds() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token != null && token.isNotEmpty) {
      try {
        final items = await _cartRepository.getCartItems();
        final filteredItems = items.where((c) => !_pendingDeletedCourseIds.contains(c.id)).toList();
        cartCoursesNotifier.value = filteredItems;
        cartCountNotifier.value = filteredItems.length;
        final ids = filteredItems.map((c) => c.id.toString()).toList();
        final key = await getCartKey();
        await prefs.setStringList(key, ids);
        return ids;
      } catch (e) {
        debugPrint('Error fetching DB cart: $e');
      }
    }

    final key = await getCartKey();
    return prefs.getStringList(key) ?? [];
  }

  static Future<void> setCartIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await getCartKey();
    await prefs.setStringList(key, ids);
  }

  static Future<void> addToCart(Course course) async {
    final courseId = course.id;
    final courseIdStr = courseId.toString();

    // 1. Optimistic memory update (0ms lag)
    final currentCourses = List<Course>.from(cartCoursesNotifier.value);
    if (!currentCourses.any((c) => c.id == courseId)) {
      currentCourses.add(course);
      cartCoursesNotifier.value = currentCourses;
      cartCountNotifier.value = currentCourses.length;
    }

    // 2. Async background sync (SharedPreferences + DB)
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final key = await getCartKey();
    final localIds = prefs.getStringList(key) ?? [];
    if (!localIds.contains(courseIdStr)) {
      localIds.add(courseIdStr);
      await prefs.setStringList(key, localIds);
    }

    if (token != null && token.isNotEmpty) {
      try {
        await _cartRepository.addItemToCart(courseId);
      } catch (e) {
        debugPrint('Error adding item to DB cart: $e');
      }
    }
  }

  static Future<void> removeFromCart(int courseId) async {
    _pendingDeletedCourseIds.add(courseId);
    final courseIdStr = courseId.toString();

    // 1. Optimistic memory update (0ms lag)
    final currentCourses = List<Course>.from(cartCoursesNotifier.value);
    currentCourses.removeWhere((c) => c.id == courseId);
    cartCoursesNotifier.value = currentCourses;
    cartCountNotifier.value = currentCourses.length;

    // 2. Async background sync (SharedPreferences + DB)
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final key = await getCartKey();
    final localIds = prefs.getStringList(key) ?? [];
    localIds.remove(courseIdStr);
    await prefs.setStringList(key, localIds);

    if (token != null && token.isNotEmpty) {
      try {
        await _cartRepository.removeItemFromCart(courseId);
      } catch (e) {
        debugPrint('Error removing item from DB cart: $e');
      } finally {
        _pendingDeletedCourseIds.remove(courseId);
      }
    } else {
      _pendingDeletedCourseIds.remove(courseId);
    }
  }

  static Future<void> syncGuestCartOnLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final guestCart = prefs.getStringList('guest_cart_course_ids') ?? [];
    if (guestCart.isNotEmpty) {
      final intIds = guestCart.map((e) => int.tryParse(e)).whereType<int>().toList();
      try {
        await _cartRepository.syncCart(intIds);
        await prefs.remove('guest_cart_course_ids');
      } catch (e) {
        debugPrint('Error syncing guest cart to DB: $e');
      }
    }
    await updateCount();
  }

  static Future<void> updateCount() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token != null && token.isNotEmpty) {
      try {
        final items = await _cartRepository.getCartItems();
        final filteredItems = items.where((c) => !_pendingDeletedCourseIds.contains(c.id)).toList();
        cartCoursesNotifier.value = filteredItems;
        cartCountNotifier.value = filteredItems.length;
        return;
      } catch (e) {
        debugPrint('Error updating DB cart count: $e');
      }
    }

    final key = await getCartKey();
    var cart = prefs.getStringList(key) ?? [];
    if (cart.isEmpty) {
      cartCoursesNotifier.value = [];
      cartCountNotifier.value = 0;
    } else {
      try {
        final allCourses = await _courseRepository.fetchCourses(search: '', filterType: 'ALL', difficulty: 'ALL');
        final filtered = allCourses.where((c) => cart.contains(c.id.toString())).toList();
        cartCoursesNotifier.value = filtered;
        cartCountNotifier.value = filtered.length;
      } catch (_) {
        cartCountNotifier.value = cart.length;
      }
    }
  }
}
