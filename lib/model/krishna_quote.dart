import 'dart:convert';

import '../services/util.dart';

/// Represents a Krishna Quote with translation support in multiple languages.
class KrishnaQuote {
  final String id;
  final String english;
  final String gujarati;
  final String hindi;
  final String sanskrit;

  KrishnaQuote({
    required this.id,
    required this.english,
    required this.gujarati,
    required this.hindi,
    required this.sanskrit,
  });

  /// Factory constructor to parse a single quote item from the JSON structure
  factory KrishnaQuote.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) {
      throw const FormatException('Empty JSON object encountered when parsing KrishnaQuote');
    }
    // Since the key is dynamic (e.g. "1", "2", "3"), we extract the first key and its value
    final String key = json.keys.first;
    final Map<String, dynamic> translations = Map<String, dynamic>.from(json[key] as Map);

    return KrishnaQuote(
      id: key,
      english: translations['en'] ?? '',
      gujarati: translations['gu'] ?? '',
      hindi: translations['hu'] ?? '',
      sanskrit: translations['sa'] ?? '',
    );
  }

  /// Helper to get a clean visual format of the quote.
  /// Prefers English, but falls back to other available languages.
  String get displayQuote {
    print("object==== $selectedLanguage");
    switch (selectedLanguage) {
      case 'en':
        return english.isNotEmpty  ? english   : _fallback;
      case 'gu':
        return gujarati.isNotEmpty ? gujarati  : _fallback;
      case 'hu':                          // was 'hu'
        return hindi.isNotEmpty    ? hindi     : _fallback;
      case 'sa':
        return sanskrit.isNotEmpty ? sanskrit  : _fallback;
      default:
        return _fallback;
    }
  }

  /// Falls back through all languages in priority order if the
  /// selected language field is empty.
  String get _fallback {
    if (english.isNotEmpty)   return english;
    if (hindi.isNotEmpty)     return hindi;
    if (gujarati.isNotEmpty)  return gujarati;
    if (sanskrit.isNotEmpty)  return sanskrit;
    return '';
  }

  Map<String, dynamic> toJson() {
    return {
      id: {
        'en': english,
        'gu': gujarati,
        'hu': hindi,
        'sa': sanskrit,
      }
    };
  }

  @override
  String toString() => 'KrishnaQuote(id: $id, en: $english)';
}

/// A wrapper class for parsing the root JSON asset file.
class KrishnaQuotesContainer {
  final List<KrishnaQuote> quotes;

  KrishnaQuotesContainer({required this.quotes});

  factory KrishnaQuotesContainer.fromJson(Map<String, dynamic> json) {
    final List<dynamic> list = json['krishnaQuotes'] as List<dynamic>? ?? [];
    final List<KrishnaQuote> parsedQuotes = list
        .map((item) => KrishnaQuote.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return KrishnaQuotesContainer(quotes: parsedQuotes);
  }

  factory KrishnaQuotesContainer.parseJsonString(String jsonString) {
    final Map<String, dynamic> decoded = json.decode(jsonString) as Map<String, dynamic>;
    return KrishnaQuotesContainer.fromJson(decoded);
  }
}
