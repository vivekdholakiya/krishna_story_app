import 'analytics_service.dart';

/// Centralizes audio-playback analytics events.
///
/// Why a wrapper class instead of calling AnalyticsService.logEvent directly:
/// - Keeps event names and parameter schemas in one place (single source of truth
///   when you later query in BigQuery)
/// - Makes the call sites in story_detail_screen.dart readable
/// - Makes it easy to add new events or change the schema without grepping
///
/// Usage in story_detail_screen.dart:
///   final analytics = AudioAnalytics(
///     storyKey: widget.storyKey,
///     categoryId: widget.categoryIndex + 1,
///     storyIndex: widget.storyIndex + 1,
///     lang: selectedLanguage,
///     voice: 'abhilash', // from manifest
///     playbackMode: 'sarvam', // or 'tts_fallback'
///   );
///   analytics.playTapped();
///   analytics.started(timeToPlayMs: 1234, cacheHit: false);
///   ...
class AudioAnalytics {
  final String storyKey;
  final int categoryId;
  final int storyIndex;
  final String lang;
  final String voice;
  final String playbackMode; // 'sarvam' | 'tts_fallback'

  // Track which milestones we've already fired so we don't double-count on replay.
  final Set<int> _milestonesReached = {};

  AudioAnalytics({
    required this.storyKey,
    required this.categoryId,
    required this.storyIndex,
    required this.lang,
    required this.voice,
    required this.playbackMode,
  });

  Map<String, Object?> get _common => {
        'story_key': storyKey,
        'category_id': categoryId,
        'story_index': storyIndex,
        'lang': lang,
        'voice': voice,
        'playback_mode': playbackMode,
      };

  // --- Engagement funnel ---

  void playTapped() {
    AnalyticsService.instance.logCustomEvent('audio_play_tap', _common);
  }

  void started({required int timeToPlayMs, required bool cacheHit}) {
    AnalyticsService.instance.logCustomEvent('audio_started', {
      ..._common,
      'time_to_play_ms': timeToPlayMs,
      'cache_hit': cacheHit,
    });
  }

  /// Call from a position-update stream. Idempotent per milestone.
  void onProgress({required int positionSec, required int durationSec}) {
    if (durationSec <= 0) return;
    final pct = (positionSec * 100 ~/ durationSec);
    for (final milestone in [25, 50, 75]) {
      if (pct >= milestone && !_milestonesReached.contains(milestone)) {
        _milestonesReached.add(milestone);
        AnalyticsService.instance.logCustomEvent('audio_progress_$milestone', _common);
      }
    }
  }

  void completed({required int durationSec}) {
    if (_milestonesReached.contains(100)) return;
    _milestonesReached.add(100);
    AnalyticsService.instance.logCustomEvent('audio_completed', {
      ..._common,
      'duration_sec': durationSec,
    });
  }

  // --- User actions ---

  void paused({required int positionSec}) {
    AnalyticsService.instance.logCustomEvent('audio_paused', {
      ..._common,
      'position_sec': positionSec,
    });
  }

  void resumed({required int positionSec}) {
    AnalyticsService.instance.logCustomEvent('audio_resumed', {
      ..._common,
      'position_sec': positionSec,
    });
  }

  void skipped({required int positionSec, required int durationSec}) {
    final pct = durationSec > 0 ? (positionSec * 100 ~/ durationSec) : 0;
    AnalyticsService.instance.logCustomEvent('audio_skipped', {
      ..._common,
      'position_sec': positionSec,
      'progress_pct': pct,
    });
  }

  // --- Download lifecycle (fire from AudioService) ---

  void downloadStarted() {
    AnalyticsService.instance.logCustomEvent('audio_download_started', {
      'story_key': storyKey,
      'lang': lang,
    });
  }

  void downloadSucceeded({required int bytes, required int durationMs}) {
    AnalyticsService.instance.logCustomEvent('audio_download_succeeded', {
      'story_key': storyKey,
      'lang': lang,
      'bytes': bytes,
      'duration_ms': durationMs,
    });
  }

  void downloadFailed({required String errorType, required String errorDetail}) {
    AnalyticsService.instance.logCustomEvent('audio_download_failed', {
      'story_key': storyKey,
      'lang': lang,
      'error_type': errorType,
      'error_detail': errorDetail.length > 100
          ? errorDetail.substring(0, 100)
          : errorDetail,
    });
  }

  void ttsFallbackUsed({required String reason}) {
    AnalyticsService.instance.logCustomEvent('audio_tts_fallback_used', {
      ..._common,
      'reason': reason,
    });
  }

  // --- Settings events (call without instantiating AudioAnalytics) ---

  static void cacheCleared({required int bytesFreed, required int filesCleared}) {
    AnalyticsService.instance.logCustomEvent('audio_cache_cleared', {
      'bytes_freed': bytesFreed,
      'files_cleared': filesCleared,
    });
  }
}
