import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Resolves story keys to Sarvam-generated audio URLs hosted on Cloudflare R2.
///
/// Loading order:
///   1. Disk cache (`<docs>/audio_manifest.json`) — from a prior session.
///   2. Network refresh from R2 (best-effort, in background).
///   3. Bundled asset (`assets/audio_manifest.json`) — last-resort fallback so
///      the app works on first launch with no network.
class AudioManifest {
  AudioManifest._();
  static final AudioManifest instance = AudioManifest._();

  static const String _remoteUrl =
      'https://pub-18b8b7f021394fefb831920c904f83e7.r2.dev/v1/audio_manifest.json';
  static const String _bundledAsset = 'assets/audio_manifest.json';
  static const String _cachedFileName = 'audio_manifest.json';
  static const Duration _httpTimeout = Duration(seconds: 8);

  final Completer<void> _ready = Completer<void>();
  Map<String, _Entry> _entries = const {};
  String? _baseUrl;
  String? _format;

  Future<void> get ready => _ready.future;
  bool get isLoaded => _ready.isCompleted;

  /// Initiate load. Safe to call multiple times — only the first call does work.
  Future<void> load() async {
    if (_ready.isCompleted) return;
    try {
      final cached = await _loadFromDisk();
      if (cached != null) _parse(cached);

      if (!_ready.isCompleted && _entries.isEmpty) {
        final bundled = await _loadFromAsset();
        if (bundled != null) _parse(bundled);
      }

      if (!_ready.isCompleted) _ready.complete();

      // Refresh from network in the background; don't block first play.
      unawaited(_refreshFromNetwork());
    } catch (_) {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  /// Returns audio info for [storyKey] if a Sarvam recording exists.
  AudioEntry? entryFor(String storyKey) {
    final e = _entries[storyKey];
    if (e == null) return null;
    return AudioEntry(url: e.url, voice: e.voice);
  }

  bool hasEntry(String storyKey) => _entries.containsKey(storyKey);

  Future<String?> _loadFromDisk() async {
    try {
      final file = await _cachedFile();
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _loadFromAsset() async {
    try {
      return await rootBundle.loadString(_bundledAsset);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshFromNetwork() async {
    try {
      final resp =
          await http.get(Uri.parse(_remoteUrl)).timeout(_httpTimeout);
      if (resp.statusCode != 200) return;
      final body = resp.body;
      _parse(body);
      final file = await _cachedFile();
      await file.writeAsString(body, flush: true);
    } catch (_) {
      // Network refresh is best-effort. Existing entries (cache or asset) remain.
    }
  }

  void _parse(String body) {
    try {
      final root = json.decode(body) as Map<String, dynamic>;
      final stories = (root['stories'] as Map?)?.cast<String, dynamic>() ?? {};
      final next = <String, _Entry>{};
      stories.forEach((key, value) {
        if (value is Map) {
          final url = value['url'] as String?;
          if (url == null || url.isEmpty) return;
          next[key] = _Entry(url: url, voice: (value['voice'] as String?) ?? '');
        }
      });
      if (next.isNotEmpty) {
        _entries = next;
        _baseUrl = root['base_url'] as String?;
        _format = root['format'] as String?;
      }
      if (!_ready.isCompleted) _ready.complete();
    } catch (_) {
      // Bad JSON — ignore and keep whatever we had before.
    }
  }

  Future<File> _cachedFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_cachedFileName');
  }

  // Exposed for tests / debugging.
  String? get baseUrl => _baseUrl;
  String? get format => _format;
  int get entryCount => _entries.length;
}

class AudioEntry {
  final String url;
  final String voice;
  const AudioEntry({required this.url, required this.voice});
}

class _Entry {
  final String url;
  final String voice;
  const _Entry({required this.url, required this.voice});
}
