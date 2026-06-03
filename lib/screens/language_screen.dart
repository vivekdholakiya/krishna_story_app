import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krishna_stories_app/services/ads.dart';
import 'package:krishna_stories_app/services/context_extensions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/analytics_service.dart';
import '../services/app_text_data.dart';
import '../services/favorite_service.dart';
import '../services/util.dart';
import '../widgets/app_background.dart';
import 'main_home_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final bool isBack;
  const LanguageSelectionScreen({super.key, required this.isBack});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _selectLanguage(String language) async {
    final fromLang = selectedLanguage;
    final toLang = languageCodes[language]!;

    selectedLanguage = toLang;
    selectedJsonFile = languageFiles[language]!;
    cachedCategories = null;
    cachedStoryDetails = null;

    final prefs = await SharedPreferences.getInstance();
    final isFirstSelection = prefs.getBool('isFirstTime') ?? true;
    await prefs.setBool('isFirstTime', false);
    await prefs.setString('selectedLanguage', selectedLanguage);
    await prefs.setString('selectedJsonFile', selectedJsonFile);

    await FavoriteService.clearAllFavorites();

    AnalyticsService.instance.logLanguageChange(
      fromLang: fromLang,
      toLang: toLang,
      isFirstSelection: isFirstSelection,
    );

    if (!mounted) return;

    // 2. Navigate
    void goHome() => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MainHomeScreen()),
          (route) => false,
        );

    if (widget.isBack) {
      adsControllerVar.showInterstititalAd(context, onRoute: goHome);
    } else {
      goHome();
    }
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
                _buildHeader(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: context.responsiveSize(20),
          vertical: context.responsiveSize(16)),
      child: Row(
        children: [
          if (widget.isBack)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(context.responsiveSize(10)),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(context.responsiveSize(14)),
                  border: Border.all(
                      color: const Color(0xFFFFD36A).withOpacity(0.4)),
                ),
                child: Icon(Icons.arrow_back,
                    color: Colors.white, size: context.responsiveSize(24)),
              ),
            ),
          if (widget.isBack) SizedBox(width: context.responsiveSize(16)),
          Expanded(
            child: Text(
              changeLanguage[selectedLanguage],
              textAlign: widget.isBack ? TextAlign.start : TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: context.responsiveFontSize(24),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: context.responsiveSize(10)),
          Image.asset('assets/images/change_lng.png',
              height: context.responsiveSize(230), fit: BoxFit.contain),
          SizedBox(height: context.responsiveSize(14)),
          Text(chooseYourLanguage["en"],
              style: TextStyle(
                  fontSize: context.responsiveFontSize(26),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFD36A))),
          if (!widget.isBack) ...[
            const Text('તમારી ભાષા પસંદ કરો',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFD36A))),
            const Text('अपनी भाषा चुनें',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFD36A))),
          ],
          SizedBox(height: context.responsiveSize(!widget.isBack ? 10 : 20)),
          ...languageFiles.keys.map((lang) => _buildLanguageCard(lang)),
          SizedBox(height: context.responsiveSize(20)),
        ],
      ),
    );
  }

  Widget _buildLanguageCard(String language) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: context.responsiveSize(24),
          vertical: context.responsiveSize(10)),
      child: GestureDetector(
        onTap: () => _selectLanguage(language),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: context.responsiveSize(16)),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(context.responsiveSize(18)),
            border: Border.all(
                color: const Color(0xFFFFD36A).withOpacity(0.35), width: 1.5),
          ),
          child: Center(
            child: Text(language,
                style: TextStyle(
                    fontSize: context.responsiveFontSize(20),
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6)),
          ),
        ),
      ),
    );
  }
}
