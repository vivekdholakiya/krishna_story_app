import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krishna_stories_app/services/ads.dart';
import 'package:krishna_stories_app/services/context_extensions.dart';
import 'package:krishna_stories_app/services/review_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_text_data.dart';
import '../services/util.dart';
import '../widgets/app_background.dart';
import '../widgets/app_header.dart';

class KrishnaQuotesScreen extends StatefulWidget {
  const KrishnaQuotesScreen({super.key});

  @override
  State<KrishnaQuotesScreen> createState() => _KrishnaQuotesScreenState();
}

class _KrishnaQuotesScreenState extends State<KrishnaQuotesScreen>
    with SingleTickerProviderStateMixin {
  // Mixed list: Map<String,dynamic> for quotes, or the String 'ad' sentinel
  List<dynamic> _displayItems = [];
  late AnimationController _fadeController;
  bool _isLoading = true;
  int _tapCount = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _loadQuotes();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadQuotes() async {
    final prefs = await SharedPreferences.getInstance();
    _tapCount = prefs.getInt('tapCount') ?? 0;

    try {
      final raw = await rootBundle.loadString('assets/krishnaQuotes2.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      final List<Map<String, dynamic>> parsed = [];

      for (final quoteObj in data['krishnaQuotes'] as List) {
        (quoteObj as Map).forEach((key, value) {
          if (value is Map) {
            parsed.add({
              'id': key,
              'en': value['en'] ?? '',
              'gu': value['gu'] ?? '',
              'hu': value['hn'] ?? '',
              'sa': value['sa'] ?? '',
            });
          }
        });
      }
      parsed.shuffle();

      setState(() {
        _displayItems = parsed;
        _isLoading = false;
      });
      _fadeController.forward();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareQuote(Map<String, dynamic> quote) async {
    final suffixMap = {
      'gu': '- ભગવાન શ્રી કૃષ્ણ',
      'hu': '- भगवान श्री कृष्ण',
      'sa': '- श्रीकृष्णः',
    };
    final text = quote[selectedLanguage] ?? quote['en'];
    final suffix = suffixMap[selectedLanguage] ?? '- Lord Krishna';
    final shareText = '$text $suffix\n\n${shareDes[selectedLanguage]}\n\n$playStoreUrl';

    _tapCount++;
    if (_tapCount >= 3) {
      _tapCount = 0;
      Share.share(shareText);
      adsControllerVar.showInterstititalAd(context, onRoute: () {});
    } else {
      Share.share(shareText);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tapCount', _tapCount);

    // Increment user engagement to trigger smart in-app review
    await ReviewService().incrementEngagement(triggerIfEligible: true);
  }

  void _copyQuote(String text) {
    Clipboard.setData(ClipboardData(text: text));
    
    // Increment user engagement to trigger smart in-app review
    ReviewService().incrementEngagement(triggerIfEligible: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: kStatusBarStyle,
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                FadeTransition(
                  opacity: _fadeController,
                  child: AppHeader(title: KrishnaQuotes[selectedLanguage]),
                ),

                Expanded(child: _buildList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD36A)));
    }
    if (_displayItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.format_quote,
                size: context.responsiveSize(72), color: const Color(0xFFFFD36A)),
            SizedBox(height: context.responsiveSize(14)),
            Text(NoQuotesFound[selectedLanguage],
                style: TextStyle(
                    color: Colors.white,
                    fontSize: context.responsiveFontSize(20),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(NoQuotesFoundDes[selectedLanguage],
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: context.responsiveFontSize(14))),
          ],
        ),
      );
    }

    // Count actual quotes (non-ad items) for index labelling
    int quoteCounter = 0;

    return ListView.builder(
      padding: EdgeInsets.symmetric(
          horizontal: context.responsiveSize(24),
          vertical: context.responsiveSize(16)),
      itemCount: _displayItems.length,
      itemBuilder: (_, i) {
        final item = _displayItems[i] as Map<String, dynamic>;
        quoteCounter++;
        return _buildQuoteCard(item, quoteCounter - 1, i);
      },
    );
  }

  Widget _buildQuoteCard(Map<String, dynamic> quote, int labelIndex, int animIndex) {
    final display = quote[selectedLanguage] ?? quote['en'];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 450 + animIndex * 40),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Transform.translate(
          offset: Offset(0, 20 * (1 - v)),
          child: Opacity(opacity: v, child: child)),
      child: Container(
        margin: EdgeInsets.only(bottom: context.responsiveSize(20)),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(context.responsiveSize(18)),
          border: Border.all(color: const Color(0xFFFFD36A).withOpacity(0.35)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              context.responsiveSize(16),
              context.responsiveSize(18),
              context.responsiveSize(16),
              context.responsiveSize(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote,
                      color: const Color(0xFFFFD36A),
                      size: context.responsiveSize(32)),
                  SizedBox(width: context.responsiveSize(12)),
                  Expanded(
                    child: Text(display,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: context.responsiveFontSize(16),
                            height: 1.6,
                            fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
              SizedBox(height: context.responsiveSize(10)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: context.responsiveSize(12),
                        vertical: context.responsiveSize(6)),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD36A).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(context.responsiveSize(12)),
                    ),
                    child: Text(
                      '#${(labelIndex + 1).toString().padLeft(2, '0')}',
                      style: TextStyle(
                          color: const Color(0xFFFFD36A),
                          fontSize: context.responsiveSize(12),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.copy,
                            color: const Color(0xFFFFD36A),
                            size: context.responsiveSize(24)),
                        onPressed: () => _copyQuote(display),
                      ),
                      IconButton(
                        icon: Icon(Icons.share,
                            color: const Color(0xFFFFD36A),
                            size: context.responsiveSize(24)),
                        onPressed: () => _shareQuote(quote),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
