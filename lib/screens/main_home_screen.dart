import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:krishna_stories_app/screens/setting_screen.dart';
import 'package:krishna_stories_app/services/context_extensions.dart';
import 'package:krishna_stories_app/services/analytics_service.dart';
import '../model/krishna_quote.dart';
import '../services/ads.dart';
import '../services/app_text_data.dart';
import '../services/util.dart';
import '../widgets/app_background.dart';
import 'category_screen.dart';
import 'favorites_screen.dart';
import 'krishna_quotes_screen.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';


class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  final GlobalKey _quoteCardKey = GlobalKey();

  // ── NEW ──────────────────────────────────────────
  KrishnaQuote? _dailyQuote;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    AnalyticsService.instance.logScreenView(
      screenName: 'MainHomeScreen',
      screenClass: 'MainHomeScreen',
    );

    adsControllerVar.loadInterstitialAd();
    adsControllerVar.loadRewardedAd();
    _loadDailyQuote(); // ── NEW
  }

  // ── NEW ──────────────────────────────────────────
  Future<void> _loadDailyQuote() async {
    try {
      final String jsonString =
      await rootBundle.loadString('assets/krishnaQuotes2.json');
      final KrishnaQuotesContainer container =
      KrishnaQuotesContainer.parseJsonString(jsonString);
      if (container.quotes.isNotEmpty) {
        // Use today's date as seed so same quote shows all day
        final int todayIndex =
            DateTime.now().dayOfYear % container.quotes.length;
        setState(() => _dailyQuote = container.quotes[todayIndex]);
      }
    } catch (e) {
      debugPrint('Failed to load daily quote: $e');
    }
  }
  // ─────────────────────────────────────────────────
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
                  // if (_dailyQuote != null) _buildDailyQuoteCard(), // ── NEW
                  SizedBox(height: context.responsiveSize(10)),
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



  Widget _buildDailyQuoteCard() {
    final quote = _dailyQuote!;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveSize(18),
        vertical: context.responsiveSize(8),
      ),
      child: RepaintBoundary(
        key: _quoteCardKey,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B1A3A), Color(0xFF102C5A)],
            ),
            borderRadius: BorderRadius.circular(context.responsiveSize(20)),
            border: Border.all(
              color: const Color(0xFFFFD36A).withOpacity(0.45),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Header ────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.responsiveSize(14),
                  vertical: context.responsiveSize(10),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD36A).withOpacity(0.07),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(context.responsiveSize(20)),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFFFFD36A).withOpacity(0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        color: const Color(0xFFFFD36A),
                        size: context.responsiveSize(15)),
                    SizedBox(width: context.responsiveSize(6)),
                    Text(
                      DailyQuote[selectedLanguage] ?? 'Daily Quote',
                      style: TextStyle(
                        fontSize: context.responsiveFontSize(12),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFFD36A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    // Share button
                    GestureDetector(
                      onTap: _shareQuoteCard,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.responsiveSize(10),
                          vertical: context.responsiveSize(5),
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD36A), Color(0xFFFFB700)],
                          ),
                          borderRadius:
                          BorderRadius.circular(context.responsiveSize(20)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.share,
                                color: const Color(0xFF0B1A3A),
                                size: context.responsiveSize(13)),
                            SizedBox(width: context.responsiveSize(4)),
                            Text(
                              Share_text[selectedLanguage] ?? 'Share',
                              style: TextStyle(
                                fontSize: context.responsiveFontSize(11),
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0B1A3A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Quote body ────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.responsiveSize(16),
                  vertical: context.responsiveSize(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '"${quote.displayQuote}"',
                      style: TextStyle(
                        fontSize: context.responsiveFontSize(13),
                        color: Colors.white,
                        height: 1.65,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Sanskrit line (always show if available)
                    if (quote.sanskrit.isNotEmpty) ...[
                      SizedBox(height: context.responsiveSize(10)),
                      Container(
                        width: context.responsiveSize(36),
                        height: 1,
                        color: const Color(0xFFFFD36A).withOpacity(0.4),
                      ),
                      SizedBox(height: context.responsiveSize(8)),
                      Text(
                        quote.sanskrit,
                        style: TextStyle(
                          fontSize: context.responsiveFontSize(11),
                          color: const Color(0xFFFFD36A).withOpacity(0.6),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _shareQuoteCard() async {
    try {
      final RenderRepaintBoundary boundary = _quoteCardKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final Directory tempDir = await getTemporaryDirectory();
      final File file = File('${tempDir.path}/krishna_daily_quote.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '🙏 ${_dailyQuote?.displayQuote ?? ''}\n\nKrishna: The Eternal Story',
      );
    } catch (e) {
      debugPrint('Share error: $e');
    }
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


