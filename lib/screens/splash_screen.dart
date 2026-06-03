import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krishna_stories_app/services/context_extensions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_text_data.dart';
import '../services/util.dart';
import '../widgets/app_background.dart';
import 'language_screen.dart';
import 'main_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  bool _isFirstTime = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this);
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic)));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: const Interval(0.3, 1.0, curve: Curves.easeIn)));
    _controller.forward();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _isFirstTime = prefs.getBool('isFirstTime') ?? true;
    selectedLanguage = prefs.getString('selectedLanguage') ?? 'hu';
    selectedJsonFile = prefs.getString('selectedJsonFile') ?? 'krishna_story_category_hindi.json';
    if (mounted) setState(() {});

    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, __, ___) =>
            // _isFirstTime ? LanguageSelectionScreen(isBack: false) :
            MainHomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: kStatusBarStyle,
      child: Scaffold(
        body: AppBackground(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => Opacity(
                opacity: _opacity.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(context.responsiveSize(26)),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.12),
                          border: Border.all(
                              color: const Color(0xFFFFD36A).withOpacity(0.5), width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 30,
                                offset: const Offset(0, 12)),
                          ],
                        ),
                        child: Icon(Icons.auto_stories,
                            size: context.responsiveSize(78),
                            color: const Color(0xFFFFD36A)),
                      ),
                      SizedBox(height: context.responsiveSize(36)),
                      Text(Krishna[selectedLanguage],
                          style: TextStyle(
                              fontSize: context.responsiveFontSize(46),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2)),
                      SizedBox(height: context.responsiveSize(6)),
                      Text(TheEternalStory[selectedLanguage],
                          style: TextStyle(
                              fontSize: context.responsiveFontSize(22),
                              color: const Color(0xFFFFD36A),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.4)),
                      SizedBox(height: context.responsiveSize(60)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) => AnimatedContainer(
                          duration: Duration(milliseconds: 600 + i * 200),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: context.responsiveSize(10),
                          height: context.responsiveSize(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _controller.value > (i + 1) / 4
                                ? const Color(0xFFFFD36A)
                                : Colors.white.withOpacity(0.3),
                          ),
                        )),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
