import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krishna_stories_app/services/context_extensions.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:krishna_stories_app/services/review_service.dart';
import 'package:krishna_stories_app/services/notification_service.dart';
import '../services/app_text_data.dart';
import '../services/audio_analytics.dart';
import '../services/audio_service.dart';
import '../services/util.dart';
import '../widgets/app_background.dart';
import '../widgets/app_header.dart';
import 'language_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_use_screen.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  bool _notifEnabled = true;
  int _notifHour = defaultNotifHour;
  int _notifMinute = defaultNotifMinute;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _loadNotifPrefs();
  }

  Future<void> _loadNotifPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifEnabled = prefs.getBool(keyNotificationsEnabled) ?? true;
      _notifHour = prefs.getInt(keyNotificationHour) ?? defaultNotifHour;
      _notifMinute = prefs.getInt(keyNotificationMinute) ?? defaultNotifMinute;
    });
  }

  Future<void> _saveNotifPrefs() async {
    await NotificationService().saveAndReschedule(
      enabled: _notifEnabled,
      hour: _notifHour,
      minute: _notifMinute,
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _notifHour, minute: _notifMinute),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFD36A),
              onPrimary: Colors.black,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _notifHour = picked.hour;
        _notifMinute = picked.minute;
      });
      await _saveNotifPrefs();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _shareApp() async {
    try {
      await Share.share(
          '${shareDes[selectedLanguage]}\n\n$playStoreUrl',
          subject: appName[selectedLanguage]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error sharing: $e')));
      }
    }
  }

  Future<void> _rateApp() async {
    try {
      await ReviewService().forceRequestReview();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open store: $e')));
      }
    }
  }

  String get _timeLabel {
    final h = _notifHour.toString().padLeft(2, '0');
    final m = _notifMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kStatusBarStyle,
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                children: [
                  AppHeader(title: Settings[selectedLanguage]),
                  Expanded(child: _buildOptions()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptions() {
    final items = [
      _SettingItem(
        icon: Icons.language,
        title: ChangeLanguage[selectedLanguage],
        subtitle: ChooseYourPreferredLanguage[selectedLanguage],
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => LanguageSelectionScreen(isBack: true))),
      ),
      _SettingItem(
        icon: Icons.share,
        title: ShareApp[selectedLanguage],
        subtitle: ShareWithFriendsAndFamily[selectedLanguage],
        onTap: _shareApp,
      ),
      _SettingItem(
        icon: Icons.star,
        title: RateApp[selectedLanguage],
        subtitle: RateUsOnTheAppStore[selectedLanguage],
        onTap: _rateApp,
      ),
      _SettingItem(
        icon: Icons.privacy_tip,
        title: PrivacyPolicy[selectedLanguage],
        subtitle: ReadOurPrivacyPolicy[selectedLanguage],
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => PrivacyPolicyScreen())),
      ),
      _SettingItem(
        icon: Icons.description,
        title: TermsOfUse[selectedLanguage],
        subtitle: ReadTermsAndConditions[selectedLanguage],
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => TermsOfUseScreen())),
      ),
    ];

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: context.responsiveSize(22)),
      children: [
        // ── Notification Card (special) ──────────────────────────
        _buildNotificationCard(),
        ...items.asMap().entries.map((e) => _buildCard(e.value, e.key + 1)),
        SizedBox(height: context.responsiveSize(30)),
      ],
    );
  }

  /// Dedicated notification settings card with toggle + time picker
  Widget _buildNotificationCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Transform.translate(
          offset: Offset(0, 20 * (1 - v)),
          child: Opacity(opacity: v, child: child)),
      child: Container(
        margin: EdgeInsets.only(bottom: context.responsiveSize(18)),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(context.responsiveSize(20)),
          border: Border.all(
              color: const Color(0xFFFFD36A).withOpacity(0.35), width: 1.5),
        ),
        child: Padding(
          padding: EdgeInsets.all(context.responsiveSize(16)),
          child: Column(
            children: [
              // ── Row 1: Toggle ──────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(context.responsiveSize(12)),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD36A).withOpacity(0.15),
                      borderRadius:
                      BorderRadius.circular(context.responsiveSize(14)),
                    ),
                    child: Icon(Icons.notifications_active_rounded,
                        color: const Color(0xFFFFD36A),
                        size: context.responsiveSize(26)),
                  ),
                  SizedBox(width: context.responsiveSize(16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Notification',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: context.responsiveFontSize(18),
                              fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: context.responsiveSize(4)),
                        Text(
                          'Receive daily Krishna quotes',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: context.responsiveFontSize(13)),
                        ),
                      ],
                    ),
                  ),
                  // Toggle switch
                  Switch(
                    value: _notifEnabled,
                    activeColor: const Color(0xFFFFD36A),
                    onChanged: (val) async {
                      setState(() => _notifEnabled = val);
                      await _saveNotifPrefs();
                    },
                  ),
                ],
              ),

              // ── Row 2: Time picker (only when enabled) ────────
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _notifEnabled
                    ? Column(
                  children: [
                    SizedBox(height: context.responsiveSize(12)),
                    Divider(
                        color: Colors.white.withOpacity(0.1), height: 1),
                    SizedBox(height: context.responsiveSize(12)),
                    GestureDetector(
                      onTap: _pickTime,
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(
                                context.responsiveSize(12)),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD36A)
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(
                                  context.responsiveSize(14)),
                            ),
                            child: Icon(Icons.access_time_rounded,
                                color: const Color(0xFFFFD36A),
                                size: context.responsiveSize(26)),
                          ),
                          SizedBox(width: context.responsiveSize(16)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Notification Time',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize:
                                      context.responsiveFontSize(18),
                                      fontWeight: FontWeight.w700),
                                ),
                                SizedBox(
                                    height: context.responsiveSize(4)),
                                Text(
                                  'Tap to change time',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize:
                                      context.responsiveFontSize(13)),
                                ),
                              ],
                            ),
                          ),
                          // Time badge
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.responsiveSize(14),
                              vertical: context.responsiveSize(8),
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFD36A),
                                  Color(0xFFFFB347)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                  context.responsiveSize(12)),
                            ),
                            child: Text(
                              _timeLabel,
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: context.responsiveFontSize(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(_SettingItem item, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 450 + index * 120),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Transform.translate(
          offset: Offset(0, 20 * (1 - v)),
          child: Opacity(opacity: v, child: child)),
      child: GestureDetector(
        onTap: item.onTap,
        child: Container(
          margin: EdgeInsets.only(bottom: context.responsiveSize(18)),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(context.responsiveSize(20)),
            border: Border.all(
                color: const Color(0xFFFFD36A).withOpacity(0.35), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(context.responsiveSize(12)),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD36A).withOpacity(0.15),
                    borderRadius:
                    BorderRadius.circular(context.responsiveSize(14)),
                  ),
                  child: Icon(item.icon,
                      color: const Color(0xFFFFD36A),
                      size: context.responsiveSize(26)),
                ),
                SizedBox(width: context.responsiveSize(16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: context.responsiveFontSize(18),
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: context.responsiveSize(4)),
                      Text(item.subtitle,
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: context.responsiveFontSize(13))),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    color: const Color(0xFFFFD36A),
                    size: context.responsiveSize(18)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingItem(
      {required this.icon,
        required this.title,
        required this.subtitle,
        required this.onTap});
}