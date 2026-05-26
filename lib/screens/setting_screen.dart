import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krishna_stories_app/services/context_extensions.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
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

  Future<void> _clearAudioCache() async {
    final result = await AudioService.instance.clearCache();
    AudioAnalytics.cacheCleared(
      bytesFreed: result.bytesFreed,
      filesCleared: result.filesCleared,
    );
    if (!mounted) return;
    final msg = result.filesCleared == 0
        ? AudioCacheEmpty[selectedLanguage]
        : '${AudioCacheCleared[selectedLanguage]} '
            '(${_formatBytes(result.bytesFreed)})';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _rateApp() async {
    final url = Uri.parse(playStoreUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open store: $e')));
      }
    }
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
        icon: Icons.delete_sweep,
        title: ClearAudioCache[selectedLanguage],
        subtitle: FreeUpSpaceFromDownloadedAudio[selectedLanguage],
        onTap: _clearAudioCache,
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

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: context.responsiveSize(22)),
      itemCount: items.length + 1,
      itemBuilder: (_, i) {
        if (i == items.length) return SizedBox(height: context.responsiveSize(30));
        return _buildCard(items[i], i);
      },
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
                    borderRadius: BorderRadius.circular(context.responsiveSize(14)),
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
