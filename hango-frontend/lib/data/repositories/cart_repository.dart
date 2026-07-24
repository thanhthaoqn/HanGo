import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/model/course.dart';
import '../../utils/config.dart';

class CartRepository {
  final String baseUrl = EnvConfig.v1BaseUrl;

  Future<List<Course>> getCartItems() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      return [];
    }

    final response = await http.get(
      Uri.parse('$baseUrl/cart'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load cart');
    }

    final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
    return body.map((json) => Course.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> addItemToCart(int courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) return;

    final response = await http.post(
      Uri.parse('$baseUrl/cart/items'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'courseId': courseId}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(body['error'] ?? 'Failed to add item to cart');
    }
  }

  Future<void> removeItemFromCart(int courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) return;

    final response = await http.delete(
      Uri.parse('$baseUrl/cart/items/$courseId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove item from cart');
    }
  }

  Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) return;

    final response = await http.delete(
      Uri.parse('$baseUrl/cart'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to clear cart');
    }
  }

  Future<void> syncCart(List<int> courseIds) async {
    if (courseIds.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) return;

    await http.post(
      Uri.parse('$baseUrl/cart/sync'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'courseIds': courseIds}),
    );
  }
}
