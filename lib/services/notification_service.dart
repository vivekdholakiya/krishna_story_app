
import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../model/krishna_quote.dart';
import 'util.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static const String _channelId = 'daily_krishna_quotes_channel';
  static const String _channelName = 'Daily Krishna Quotes';
  static const String _channelDesc =
      'Receives one daily inspirational quote from Krishna : The Eternal Story at 9:00 AM.';

  static const int _scheduleDaysCount = 30;
  static const int _notificationIdOffset = 1000;

  static final List<Map<String, dynamic>> _fallbackQuotesJson = [
    {
      "1": {
        "en": "You have the right to perform your duty, but never to the fruits of action.",
        "gu": "તમારો અધિકાર છે કર્મ કરવાનો, પરંતુ ફળનો અધિકાર નથી.",
        "hu": "तुम्हारा अधिकार है कर्म करने का, लेकिन फल का अधिकार नहीं है।",
        "sa": "कर्मण्येवाधिकारस्ते मा फलेषु कदाचन।"
      }
    },
    {
      "2": {
        "en": "Perform your obligatory duty, action is better than inaction.",
        "gu": "તમારું કર્તવ્ય કરો, કર્મ અકર્મ કરતાં શ્રેષ્ઠ છે.",
        "hu": "अपना नियत कर्तव्य करो, कर्म अकर्म से श्रेष्ठ है।",
        "sa": "कर्म ज्यायो ह्यकर्मणः।"
      }
    },
    {
      "3": {
        "en": "The mind is restless, but it can be controlled by practice and detachment.",
        "gu": "મન ચંચળ છે, પરંતુ અભ્યાસ અને વૈરાગ્યથી તેને વશ કરી શકાય છે.",
        "hu": "मन चंचल है, लेकिन अभ्यास और वैराग्य से इसे वश में किया जा सकता है।",
        "sa": "अभ्यासेन तु कौन्तेय वैराग्येण च गृह्यते।"
      }
    }
  ];

  Future<void> initialize() async {
    try {
      tz.initializeTimeZones();
      final TimezoneInfo timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
      developer.log('Timezone initialized to: ${timeZoneInfo.identifier}', name: 'NotificationService');

      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _localNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotification,
      );

      developer.log('Flutter Local Notifications Plugin Initialized successfully', name: 'NotificationService');

      await requestPermissions();
      await scheduleDailyQuotes();
    } catch (e, stacktrace) {
      developer.log(
        'Error initializing NotificationService: $e',
        error: e,
        stackTrace: stacktrace,
        name: 'NotificationService',
      );
    }
  }

  void _onDidReceiveNotification(NotificationResponse details) {
    developer.log(
      'Notification clicked! Payload: ${details.payload}',
      name: 'NotificationService',
    );
  }

  Future<bool> requestPermissions() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      bool androidGranted = false;
      if (androidImplementation != null) {
        androidGranted =
            await androidImplementation.requestNotificationsPermission() ?? false;

        // ── NEW: Request exact alarm permission on Android 12+ ──────────────
        // This opens the system settings screen where the user can grant
        // "Alarms & Reminders" permission. Without it, exactAllowWhileIdle throws.
        final bool? exactAlarmGranted =
        await androidImplementation.requestExactAlarmsPermission();
        developer.log(
          'Exact alarm permission granted: $exactAlarmGranted',
          name: 'NotificationService',
        );
        // ───────────────────────────────────────────────────────────────────

        developer.log(
          'Android notification permission status: $androidGranted',
          name: 'NotificationService',
        );
      }



      return androidGranted;
    } catch (e) {
      developer.log('Failed to request permissions: $e', name: 'NotificationService');
      return false;
    }
  }

  Future<List<KrishnaQuote>> _loadQuotesFromAsset() async {
    try {
      final String jsonString =
      await rootBundle.loadString('assets/krishnaQuotes2.json');
      final KrishnaQuotesContainer container =
      KrishnaQuotesContainer.parseJsonString(jsonString);
      if (container.quotes.isNotEmpty) return container.quotes;
    } catch (e) {
      developer.log('Error loading quotes from asset (using fallback): $e',
          name: 'NotificationService');
    }
    return _fallbackQuotesJson.map((item) => KrishnaQuote.fromJson(item)).toList();
  }

  /// Resolves the best available AndroidScheduleMode for this device.
  /// - Tries exactAllowWhileIdle first (most reliable).
  /// - Falls back to inexactAllowWhileIdle if exact alarms are not permitted.
  ///   Inexact alarms are delivered within a ~15-minute window but don't need
  ///   the SCHEDULE_EXACT_ALARM permission.
  Future<AndroidScheduleMode> _resolveScheduleMode() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImpl =
          _localNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        final bool canScheduleExact =
            await androidImpl.canScheduleExactNotifications() ?? false;

        developer.log(
          'canScheduleExactNotifications: $canScheduleExact',
          name: 'NotificationService',
        );

        if (canScheduleExact) return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (e) {
      developer.log(
        'Error checking exact alarm capability, falling back to inexact: $e',
        name: 'NotificationService',
      );
    }

    // Safe fallback — works without any special permission
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> scheduleDailyQuotes() async {
    try {
      // ── Read user's saved notification preference ──────────────
      final prefs = await SharedPreferences.getInstance();
      final bool enabled = prefs.getBool(keyNotificationsEnabled) ?? true;

      if (!enabled) {
        developer.log(
          'Notifications disabled by user. Skipping schedule.',
          name: 'NotificationService',
        );
        await cancelAllNotifications();
        return;
      }

      final int hour = prefs.getInt(keyNotificationHour) ?? defaultNotifHour;
      final int minute = prefs.getInt(keyNotificationMinute) ?? defaultNotifMinute;
      // ────────────────────────────────────────────────────────────

      final List<KrishnaQuote> quotes = await _loadQuotesFromAsset();
      if (quotes.isEmpty) {
        developer.log('No quotes available to schedule.', name: 'NotificationService');
        return;
      }

      final AndroidScheduleMode scheduleMode = await _resolveScheduleMode();
      developer.log('Using AndroidScheduleMode: $scheduleMode', name: 'NotificationService');

      final Random random = Random();
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

      developer.log(
        'Scheduling daily Krishna quotes starting from current local time: $now',
        name: 'NotificationService',
      );

      const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
        showWhen: true,
        playSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      for (int i = 0; i < _scheduleDaysCount; i++) {
        tz.TZDateTime scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day + i,
          hour,    // ← user's saved hour
          minute,  // ← user's saved minute
        );

        // If today's slot has already passed, push to tomorrow
        if (i == 0 && scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }

        final KrishnaQuote selectedQuote = quotes[random.nextInt(quotes.length)];
        final int notificationId = _notificationIdOffset + i;

        await _localNotificationsPlugin.zonedSchedule(
          id: notificationId,
          title: "Krishna : The Eternal Story",
          body: selectedQuote.displayQuote,
          scheduledDate: scheduledDate,
          notificationDetails: notificationDetails,
          androidScheduleMode: scheduleMode,
        );

        developer.log(
          'Scheduled quote #$notificationId (Day $i) for: $scheduledDate | Mode: $scheduleMode',
          name: 'NotificationService',
        );
      }

      developer.log(
        'Successfully scheduled $_scheduleDaysCount days of daily Krishna quotes.',
        name: 'NotificationService',
      );
    } catch (e, stacktrace) {
      developer.log(
        'Failed to schedule daily notifications: $e',
        error: e,
        stackTrace: stacktrace,
        name: 'NotificationService',
      );
    }
  }
  Future<void> cancelAllNotifications() async {
    try {
      await _localNotificationsPlugin.cancelAll();
      developer.log('All scheduled notifications cancelled successfully.',
          name: 'NotificationService');
    } catch (e) {
      developer.log('Failed to cancel notifications: $e', name: 'NotificationService');
    }
  }

  Future<void> checkPendingNotifications() async {
    try {
      final List<PendingNotificationRequest> pendingRequests =
      await _localNotificationsPlugin.pendingNotificationRequests();
      developer.log(
        '--- Pending Notifications Count: ${pendingRequests.length} ---',
        name: 'NotificationService',
      );
      for (var request in pendingRequests) {
        developer.log(
          'Pending ID: ${request.id} | Title: "${request.title}" | Body: "${request.body}"',
          name: 'NotificationService',
        );
      }
    } catch (e) {
      developer.log('Failed to check pending notifications: $e', name: 'NotificationService');
    }
  }


  /// Called from settings when user changes time or toggle.
  Future<void> saveAndReschedule({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyNotificationsEnabled, enabled);
    await prefs.setInt(keyNotificationHour, hour);
    await prefs.setInt(keyNotificationMinute, minute);
    await cancelAllNotifications();
    if (enabled) await scheduleDailyQuotes();
  }

}

