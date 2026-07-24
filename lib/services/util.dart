import '../model/caregory_model.dart';

// ── Language Config ──────────────────────────────────────────────
const Map<String, String> languageFiles = {
  'English': 'krishna_story_category_english.json',
  'ગુજરાતી': 'krishna_story_category_gujrati.json',
  'हिन्दी': 'krishna_story_category_hindi.json',
  'संस्कृत': 'krishna_story_category_sanskrit.json',
};

const Map<String, String> languageCodes = {
  'English': 'en',
  'ગુજરાતી': 'gu',
  'हिन्दी': 'hu',
  'संस्कृत': 'sa',
};

String selectedLanguage = 'en';
String selectedJsonFile = 'krishna_story_category_hindi.json';

// ── URLs ─────────────────────────────────────────────────────────

const String playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.vivek.krishna.stories';

// ── Ad Unit IDs ──────────────────────────────────────────────────

// const String interstitialId = 'ca-app-pub-8791243074795894/7940378110';
// const String rewardedAdId = 'ca-app-pub-8791243074795894/6627296447';
// const String bannerAdId = 'ca-app-pub-8791243074795894/5576540829';
// const String openAdId = 'ca-app-pub-8791243074795894/5576540829';
// const String nativeAdId = 'ca-app-pub-8791243074795894/5576540829';

//── Test Ad Unit IDs ─────────────────────────────────────────────

const String interstitialId = 'ca-app-pub-3940256099942544/1033173712';
const String rewardedAdId = 'ca-app-pub-3940256099942544/5224354917';
const String bannerAdId = 'ca-app-pub-3940256099942544/6300978111';
const String openAdId = 'ca-app-pub-3940256099942544/9257395921';
const String nativeAdId = 'ca-app-pub-3940256099942544/2247696110';

// ── Data Cache ───────────────────────────────────────────────────

List<StoryCategory>? cachedCategories;
Map<String, dynamic>? cachedStoryDetails;

const String keyNotificationsEnabled = 'notif_enabled';
const String keyNotificationHour = 'notif_hour';
const String keyNotificationMinute = 'notif_minute';

const int defaultNotifHour = 9;
const int defaultNotifMinute = 30;

extension DateTimeExt on DateTime {
  int get dayOfYear {
    return difference(DateTime(year, 1, 1)).inDays;
  }
}
