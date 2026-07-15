
import 'dart:developer';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service responsible for managing in-app ratings and reviews.
/// Implements Google Play compliant smart trigger limits to prevent popup spam.
class ReviewService {
  // Singleton pattern
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  final InAppReview _inAppReview = InAppReview.instance;

  // SharedPreferences Keys
  static const String _keyHasReviewed = 'review_has_reviewed';
  static const String _keyLaunchCount = 'review_launch_count';
  static const String _keyEngagementCount = 'review_engagement_count';
  static const String _keyFirstLaunchTime = 'review_first_launch_time';
  static const String _keyLastPromptTime = 'review_last_prompt_time';

  // Smart trigger configuration constants
  static const int _minLaunchCount = 1;
  static const int _minEngagementCount = 3;
  static const int _minDaysSinceFirstLaunch = 0; // Prompt only after at least 3 days of usage
  static const int _cooldownDays = 3;        // Cooldown period between prompts to prevent spam (14 days)

  /// Initializes the service, registers a new launch, and sets up tracking state.
  /// Should be called on app startup.
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Increment launch count
      final int currentLaunches = prefs.getInt(_keyLaunchCount) ?? 0;
      await prefs.setInt(_keyLaunchCount, currentLaunches + 1);

      // 2. Initialize first launch time if not set
      if (prefs.getInt(_keyFirstLaunchTime) == null) {
        await prefs.setInt(_keyFirstLaunchTime, DateTime.now().millisecondsSinceEpoch);
      }

      log(
        'ReviewService initialized. Total launches: ${currentLaunches + 1}',
        name: 'ReviewService',
      );
    } catch (e) {
      log('Error initializing ReviewService: $e', name: 'ReviewService');
    }
  }

  /// Increments user engagement count (e.g. when user reads a story or adds to favorites).
  /// If [triggerIfEligible] is true, it checks trigger rules and attempts a review request.
  Future<void> incrementEngagement({bool triggerIfEligible = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int currentEngagements = prefs.getInt(_keyEngagementCount) ?? 0;
      final int newEngagements = currentEngagements + 1;
      await prefs.setInt(_keyEngagementCount, newEngagements);

      log(
        'Engagement count incremented: $newEngagements',
        name: 'ReviewService',
      );

      if (triggerIfEligible && await shouldAskForReview()) {
        await requestReview();
      }
    } catch (e) {
      log('Error incrementing engagement: $e', name: 'ReviewService');
    }
  }


  Future<bool> shouldAskForReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Check if user already successfully reviewed/declined permanently
      final bool hasReviewed = prefs.getBool(_keyHasReviewed) ?? false;
      if (hasReviewed) {
        log('shouldAskForReview: False (Already reviewed/dismissed)', name: 'ReviewService');
        return false;
      }

      // 2. Check Launch Count threshold
      final int launches = prefs.getInt(_keyLaunchCount) ?? 0;
      if (launches < _minLaunchCount) {
        log('shouldAskForReview: False (Launches $launches < $_minLaunchCount)', name: 'ReviewService');
        return false;
      }

      // 3. Check Engagement Count threshold
      final int engagements = prefs.getInt(_keyEngagementCount) ?? 0;
      if (engagements < _minEngagementCount) {
        log('shouldAskForReview: False (Engagements $engagements < $_minEngagementCount)', name: 'ReviewService');
        return false;
      }

      // 4. Check cooldown period since last prompt
      final int lastPromptMs = prefs.getInt(_keyLastPromptTime) ?? 0;
      if (lastPromptMs > 0) {
        final DateTime lastPromptDate = DateTime.fromMillisecondsSinceEpoch(lastPromptMs);
        final int daysSinceLastPrompt = DateTime.now().difference(lastPromptDate).inDays;
        if (daysSinceLastPrompt < _cooldownDays) {
          log('shouldAskForReview: False (In cooldown. Days since last prompt: $daysSinceLastPrompt)', name: 'ReviewService');
          return false;
        }
      }

      log('shouldAskForReview: True (All triggers and thresholds satisfied!)', name: 'ReviewService');
      return true;
    } catch (e) {
      log('Error evaluating shouldAskForReview: $e', name: 'ReviewService');
      return false;
    }
  }

  /// Triggers the native in-app review flow.
  /// Automatically falls back to the Google Play Store listing page if unavailable.
  Future<void> requestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Update last prompt timestamp immediately to ensure cooldown enforcement
      await prefs.setInt(_keyLastPromptTime, DateTime.now().millisecondsSinceEpoch);

      // Check if native in-app review popup is available on the device
      final bool isNativeFlowAvailable = await _inAppReview.isAvailable();

      if (isNativeFlowAvailable) {
        log('Native Google Play in-app review flow is available. Launching...', name: 'ReviewService');
        await _inAppReview.requestReview();
        // Set hasReviewed to true because requestReview is complete
        await prefs.setBool(_keyHasReviewed, true);
        log('Native review completed/shown successfully.', name: 'ReviewService');
      } else {
        log('Native review unavailable. Falling back to Store Listing page.', name: 'ReviewService');
        await openStoreListing();
      }
    } catch (e) {
      log('Failed to execute requestReview flow: $e', name: 'ReviewService');
      // If native dialog errors out, try opening store listing directly
      await openStoreListing();
    }
  }

  /// Direct fallback to open the app's Google Play Store listing page.
  /// Does not require hardcoding package names, as the plugin auto-detects it.
  Future<void> openStoreListing() async {
    try {
      log('Opening store listing page directly.', name: 'ReviewService');
      await _inAppReview.openStoreListing();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasReviewed, true); // Mark as reviewed to prevent subsequent dialog prompts
    } catch (e) {
      log('Error opening store listing page: $e', name: 'ReviewService');
    }
  }

  /// Forces the review flow immediately (bypass all smart trigger thresholds).
  /// Extremely useful for "Rate Us" clicks inside settings or menu options.
  Future<void> forceRequestReview() async {
    log('Forced review request triggered (Settings bypass mode).', name: 'ReviewService');
    await requestReview();
  }

  /// Helper to reset review prompts and counts (for development testing purposes).
  Future<void> debugResetReviewState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHasReviewed);
      await prefs.remove(_keyLaunchCount);
      await prefs.remove(_keyEngagementCount);
      await prefs.remove(_keyFirstLaunchTime);
      await prefs.remove(_keyLastPromptTime);
      log('Review tracking states have been debug-reset successfully.', name: 'ReviewService');
    } catch (e) {
      log('Failed to reset review state: $e', name: 'ReviewService');
    }
  }
}
