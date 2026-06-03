import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'audio_manifest.dart';

/// Fetches Sarvam-generated story audio from R2 and caches it on disk.
///
/// The first play for a story streams from R2 and saves the bytes; subsequent
/// plays read the cached file. `clearCache()` is wired to the Settings screen.

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const String _cacheDirName = 'audio_cache';
  static const Duration _downloadTimeout = Duration(seconds: 30);

  final Map<String, Future<File?>> _inflight = {};

  /// Returns the cached file if present, otherwise downloads it.
  /// Returns `null` if no manifest entry exists or the download fails.
  ///
  /// [onCacheHit] (optional) is invoked synchronously with `true` if the file
  /// was already on disk before this call — useful for analytics.
  Future<File?> getAudio(
    String storyKey, {
    void Function(bool cacheHit)? onCacheHit,
  }) async {
    await AudioManifest.instance.ready;
    final entry = AudioManifest.instance.entryFor(storyKey);
    if (entry == null) {
      onCacheHit?.call(false);
      return null;
    }

    final file = await _fileFor(entry.url);
    if (await file.exists() && await file.length() > 0) {
      onCacheHit?.call(true);
      return file;
    }
    onCacheHit?.call(false);

    // De-dupe concurrent fetches for the same URL.
    final existing = _inflight[entry.url];
    if (existing != null) return existing;
    final future = _download(entry.url, file);
    _inflight[entry.url] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(entry.url);
    }
  }

  Future<File?> _download(String url, File target) async {
    try {
      final resp =
          await http.get(Uri.parse(url)).timeout(_downloadTimeout);
      if (resp.statusCode != 200) return null;
      await target.parent.create(recursive: true);
      await target.writeAsBytes(resp.bodyBytes, flush: true);
      return target;
    } catch (_) {
      return null;
    }
  }

  Future<File> _fileFor(String url) async {
    final dir = await _cacheDir();
    final name = _safeFileName(url);
    return File('${dir.path}/$name');
  }

  Future<Directory> _cacheDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/$_cacheDirName');
  }

  /// Reuses the URL's last two path segments so language stays in the filename.
  /// e.g. `.../v1/hu/01_01.opus` → `hu_01_01.opus`.
  String _safeFileName(String url) {
    final segments = Uri.parse(url).pathSegments;
    if (segments.length >= 2) {
      return '${segments[segments.length - 2]}_${segments.last}';
    }
    return segments.isNotEmpty
        ? segments.last
        : url.hashCode.toRadixString(16);
  }

  /// Deletes every cached audio file. Returns `(bytesFreed, filesCleared)`.
  Future<({int bytesFreed, int filesCleared})> clearCache() async {
    try {
      final dir = await _cacheDir();
      if (!await dir.exists()) {
        return (bytesFreed: 0, filesCleared: 0);
      }
      var bytes = 0;
      var files = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          try {
            bytes += await entity.length();
            await entity.delete();
            files += 1;
          } catch (_) {
            // skip files we can't delete
          }
        }
      }
      return (bytesFreed: bytes, filesCleared: files);
    } catch (_) {
      return (bytesFreed: 0, filesCleared: 0);
    }
  }

  /// Total bytes currently stored in the cache directory.
  Future<int> cacheSizeBytes() async {
    try {
      final dir = await _cacheDir();
      if (!await dir.exists()) return 0;
      var bytes = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          try {
            bytes += await entity.length();
          } catch (_) {}
        }
      }
      return bytes;
    } catch (_) {
      return 0;
    }
  }
}
