import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/flashcard.dart';

class FlashcardRepository {
  final String baseUrl = 'http://localhost:8080/api/v1/flashcards';

  // Singleton instance
  static final FlashcardRepository _instance = FlashcardRepository._internal();
  factory FlashcardRepository() => _instance;
  FlashcardRepository._internal();

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetches flashcard collections, optionally filtered by status.
  /// status can be: 'All', 'Recents', 'Learned', 'Created'
  Future<List<FlashcardCollection>> fetchCollections({String status = 'All'}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/collections?status=$status'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList
            .map((item) => FlashcardCollection.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized. Please log in again.');
      } else {
        throw Exception('Failed to load collections: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching collections: $e');
    }
  }

  /// Creates a new flashcard collection.
  Future<void> createCollection(FlashcardCollection collection) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/collections'),
        headers: headers,
        body: jsonEncode(collection.toJson()),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create collection: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating collection: $e');
    }
  }

  /// Updates a collection (e.g. adding cards, changing title).
  Future<void> updateCollection(FlashcardCollection collection) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/collections/${collection.id}'),
        headers: headers,
        body: jsonEncode(collection.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update collection: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating collection: $e');
    }
  }

  /// Deletes a collection.
  Future<void> deleteCollection(String collectionId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/collections/$collectionId'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete collection: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting collection: $e');
    }
  }

  /// Marks a specific card inside a collection as learned/unlearned.
  Future<void> markCardAsLearned(String collectionId, String cardId, bool isLearned) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/collections/$collectionId/cards/$cardId/learn?isLearned=$isLearned'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark card: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error marking card as learned: $e');
    }
  }

  /// Marks a collection as recently studied.
  Future<void> touchCollection(String collectionId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/collections/$collectionId/touch'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to touch collection: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error touching collection: $e');
    }
  }
}
