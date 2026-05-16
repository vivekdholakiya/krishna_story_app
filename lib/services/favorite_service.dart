import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteStory {
  final String storyKey;
  final String title;
  final String content;
  final int categoryIndex;
  final int storyIndex;
  final String categoryName;

  const FavoriteStory({
    required this.storyKey,
    required this.title,
    required this.content,
    required this.categoryIndex,
    required this.storyIndex,
    required this.categoryName,
  });

  Map<String, dynamic> toJson() => {
        'storyKey': storyKey,
        'title': title,
        'content': content,
        'categoryIndex': categoryIndex,
        'storyIndex': storyIndex,
        'categoryName': categoryName,
      };

  factory FavoriteStory.fromJson(Map<String, dynamic> json) => FavoriteStory(
        storyKey: json['storyKey'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        categoryIndex: json['categoryIndex'] as int,
        storyIndex: json['storyIndex'] as int,
        categoryName: json['categoryName'] as String,
      );
}

class FavoriteService {
  static const String _key = 'favorite_stories';

  static Future<List<FavoriteStory>> getFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);
      if (jsonString == null || jsonString.isEmpty) return [];
      final list = jsonDecode(jsonString) as List;
      return list
          .map((e) => FavoriteStory.fromJson(e as Map<String, dynamic>))
          .toList()
          .reversed
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> addToFavorites(FavoriteStory story) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await getFavorites();
      if (favorites.any((s) => s.storyKey == story.storyKey)) return false;
      favorites.insert(0, story);
      return await prefs.setString(
          _key, jsonEncode(favorites.map((s) => s.toJson()).toList()));
    } catch (_) {
      return false;
    }
  }

  static Future<bool> removeFromFavorites(String storyKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await getFavorites();
      favorites.removeWhere((s) => s.storyKey == storyKey);
      return await prefs.setString(
          _key, jsonEncode(favorites.map((s) => s.toJson()).toList()));
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isFavorite(String storyKey) async {
    try {
      return (await getFavorites()).any((s) => s.storyKey == storyKey);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clearAllFavorites() async {
    try {
      return (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {
      return false;
    }
  }
}
