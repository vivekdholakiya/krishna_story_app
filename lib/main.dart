import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:krishna_stories_app/services/network_manager.dart';
import 'screens/splash_screen.dart';
import 'services/ads.dart';

final internetService = InternetService();
final FirebaseAnalytics _firebaseAnalytics = FirebaseAnalytics.instance;

const firebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyDiPKRQK85AHvqnNpcF53Bvz1ZIDCMNKRI",
  appId: "1:291416346723:android:aca41430d576f6d6a32856",
  messagingSenderId: "291416346723",
  projectId: "krishna-story-app",
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);

  await MobileAds.instance.initialize();
  AdsControllerMain.markMobileAdsInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => internetService.init());
  }

  @override
  void dispose() {
    internetService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: internetService.navigatorKey,
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: _firebaseAnalytics),
      ],
      home: const SplashScreen(),
    );
  }
}
