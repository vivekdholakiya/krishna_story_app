import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krishna_stories_app/screens/setting_screen.dart';
import 'package:krishna_stories_app/services/context_extensions.dart';
import 'package:krishna_stories_app/services/analytics_service.dart';
import '../services/ads.dart';
import '../services/app_text_data.dart';
import '../services/util.dart';
import '../widgets/app_background.dart';
import 'category_screen.dart';
import 'favorites_screen.dart';
import 'krishna_quotes_screen.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen>
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

    AnalyticsService.instance.logScreenView(
      screenName: 'MainHomeScreen',
      screenClass: 'MainHomeScreen',
    );

    adsControllerVar.loadInterstitialAd();
    adsControllerVar.loadRewardedAd();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                  _buildHeader(),
                  Expanded(child: _buildOptions()),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: const AdsBannerWidget(),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: context.responsiveSize(18),
          vertical: context.responsiveSize(12)),
      child: Column(
        children: [
          // Logo image — no debug tap handler
          Image.asset(
            'assets/images/setting_first.png',
            height: context.responsiveSize(MediaQuery.sizeOf(context).height * 0.28),
          ),
          SizedBox(height: context.responsiveSize(10)),
          Text(krishna[selectedLanguage],
              style: TextStyle(
                  fontSize: context.responsiveFontSize(36),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2)),
          Text(the_ethernal_story[selectedLanguage],
              style: TextStyle(
                  fontSize: context.responsiveFontSize(22),
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFFFD36A))),
        ],
      ),
    );
  }

  Widget _buildOptions() {
    final options = [
      _Option(
        icon: 'assets/images/story.png',
        title: devine_krishna_leelas[selectedLanguage],
        subtitle: begin_divine_leelas_of_lord_krishna[selectedLanguage],
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => CategoryScreen())),
      ),
      _Option(
        icon: 'assets/images/fav.png',
        title: favourite_stories[selectedLanguage],
        subtitle: your_most_loved_krishna_tales[selectedLanguage],
        onTap: () {
          adsControllerVar.showInterstititalAd(context, onRoute: () {Navigator.push(context,
              MaterialPageRoute(builder: (_) => FavoritesScreen()));});
        },
      ),
      _Option(
        icon: 'assets/images/gallery.png',
        title: Krishnas_Quotes[selectedLanguage],
        subtitle: divine_thoughts_and_teachings_of_Krishna[selectedLanguage],
        onTap: () {
          adsControllerVar.showInterstititalAd(context, onRoute: () {Navigator.push(context,
              MaterialPageRoute(builder: (_) => KrishnaQuotesScreen()));});

        },
      ),
      _Option(
        icon: 'assets/images/setting.png',
        title: Sacred_Settings[selectedLanguage],
        subtitle: personalize_your_spiritual_reading_experience[selectedLanguage],
        onTap: () {
          adsControllerVar.showInterstititalAd(context, onRoute: () {Navigator.push(context,
              MaterialPageRoute(builder: (_) => SettingScreen()));});

        },
      ),
    ];

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: context.responsiveSize(22)),
      itemCount: options.length + 1, // +1 for bottom spacing
      itemBuilder: (context, i) {
        if (i == options.length) return SizedBox(height: context.responsiveSize(30));
        return _buildOptionCard(options[i], i);
      },
    );
  }

  Widget _buildOptionCard(_Option opt, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + index * 120),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child)),
      child: GestureDetector(
        onTap: opt.onTap,
        child: Container(
          margin: EdgeInsets.only(bottom: context.responsiveSize(18)),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(context.responsiveSize(22)),
            border: Border.all(
                color: const Color(0xFFFFD36A).withOpacity(0.35), width: 1.5),
          ),
          child: Padding(
            padding: EdgeInsets.all(context.responsiveSize(14)),
            child: Row(
              children: [
                Image.asset(opt.icon, height: context.responsiveSize(70)),
                SizedBox(width: context.responsiveSize(14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(opt.title,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: context.responsiveFontSize(18),
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: context.responsiveSize(4)),
                      Text(opt.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: context.responsiveSize(13))),
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

class _Option {
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Option(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
}
