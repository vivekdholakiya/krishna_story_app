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
}

