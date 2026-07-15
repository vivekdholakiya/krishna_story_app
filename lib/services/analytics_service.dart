import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalytics get analytics => _analytics;

  Future<void> logAppOpen() => _analytics.logAppOpen();

  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) {
    return _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }

  Future<void> logAdImpression({
    required String adUnit,
    required String adFormat,
  }) {
    return _analytics.logEvent(
      name: 'ad_impression',
      parameters: {
        'ad_unit': adUnit,
        'ad_format': adFormat,
      },
    );
  }

  Future<void> logAdClick({
    required String adUnit,
    required String adFormat,
  }) {
    return _analytics.logEvent(
      name: 'ad_click',
      parameters: {
        'ad_unit': adUnit,
        'ad_format': adFormat,
      },
    );
  }

  Future<void> logRewardedAdEarned({
    required String adUnit,
    num? rewardAmount,
    String? rewardType,
  }) {
    return _analytics.logEvent(
      name: 'rewarded_ad_earned',
      parameters: {
        'ad_unit': adUnit,
        if (rewardAmount != null) 'reward_amount': rewardAmount,
        if (rewardType != null) 'reward_type': rewardType,
      },
    );
  }

  Future<void> logInterstitialShown({required String adUnit}) {
    return _analytics.logEvent(
      name: 'interstitial_shown',
      parameters: {
        'ad_unit': adUnit,
      },
    );
  }

  /// Generic event logger for ad-hoc events (e.g. audio playback analytics).
  /// Firebase requires parameter values to be String, num, or bool — nulls are dropped.
// AFTER:
  Future<void> logCustomEvent(String name, Map<String, Object?> params) {
    final cleaned = <String, Object>{};
    params.forEach((k, v) {
      if (v == null) return;
      // Firebase accepts only String or num — convert bool to 1/0
      cleaned[k] = v is bool ? (v ? 1 : 0) : v;  // ✅
    });
    return _analytics.logEvent(name: name, parameters: cleaned);
  }

  // ── Navigation & engagement events ─────────────────────────────────

  Future<void> logCategoryTap({
    required int categoryIndex,
    required String categoryName,
    required String lang,
  }) {
    return logCustomEvent('category_tap', {
      'category_id': categoryIndex + 1,
      'category_name': categoryName,
      'lang': lang,
    });
  }

  Future<void> logStoryTap({
    required String storyKey,
    required int categoryIndex,
    required int storyIndex,
    required String lang,
    required bool wasAdGated,
  }) {
    return logCustomEvent('story_tap', {
      'story_key': storyKey,
      'category_id': categoryIndex + 1,
      'story_index': storyIndex + 1,
      'lang': lang,
      'was_ad_gated': wasAdGated,
    });
  }

  Future<void> logLanguageChange({
    required String fromLang,
    required String toLang,
    required bool isFirstSelection,
  }) {
    return logCustomEvent('language_change', {
      'from_lang': fromLang,
      'to_lang': toLang,
      'is_first_selection': isFirstSelection,
    });
  }

  Future<void> logFavoriteToggle({
    required String storyKey,
    required int categoryIndex,
    required int storyIndex,
    required String lang,
    required bool added, // true = added, false = removed
  }) {
    return logCustomEvent('favorite_toggle', {
      'story_key': storyKey,
      'category_id': categoryIndex + 1,
      'story_index': storyIndex + 1,
      'lang': lang,
      'added': added,
    });
  }

  Future<void> logSearch({
    required String query,
    required int resultCount,
    required String lang,
  }) {
    return logCustomEvent('search', {
      // Truncate to 100 chars so we don't blow Firebase's param size limit
      // and don't store anything sensitive if user types weird input.
      'query': query.length > 100 ? query.substring(0, 100) : query,
      'query_length': query.length,
      'result_count': resultCount,
      'lang': lang,
    });
  }

  Future<void> logStoryScroll({
    required String storyKey,
    required int categoryIndex,
    required int storyIndex,
    required String lang,
    required int milestone, // 25, 50, 75, 100
  }) {
    return logCustomEvent('story_scroll_$milestone', {
      'story_key': storyKey,
      'category_id': categoryIndex + 1,
      'story_index': storyIndex + 1,
      'lang': lang,
    });
  }
}

