import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:krishna_stories_app/services/app_text_data.dart';
import 'package:krishna_stories_app/services/context_extensions.dart';
import 'package:krishna_stories_app/services/analytics_service.dart';
import 'util.dart';

// Change to production IDs before release:
// AdsControllerMain(interstitialId: interstitialId, rewardedId: rewardedAdId, bannerId: '...')
final AdsControllerMain adsControllerVar = AdsControllerMain(
  interstitialId: interstitialId,
  rewardedId: rewardedAdId,
  bannerId: bannerAdId,
);

class AdsControllerMain {
  static final ValueNotifier<bool> mobileAdsInitialized = ValueNotifier<bool>(false);

  static void markMobileAdsInitialized() {
    if (!mobileAdsInitialized.value) mobileAdsInitialized.value = true;
  }

  final String interstitialId;
  final String rewardedId;
  final String bannerId;
  AppOpenAd? _appOpenAd;
  bool _isAppOpenAdShowing = false;

  AdsControllerMain({
    required this.interstitialId,
    required this.rewardedId,
    required this.bannerId,
  }) {
    _getUserConsent();
  }


  Future<bool> _ensureMobileAdsReady() async {
    if (mobileAdsInitialized.value) return true;

    final completer = Completer<bool>();

    void listener() {
      if (mobileAdsInitialized.value && !completer.isCompleted) {
        completer.complete(true);
        mobileAdsInitialized.removeListener(listener);
      }
    }

    mobileAdsInitialized.addListener(listener);

    try {
      return await completer.future
          .timeout(const Duration(seconds: 8), onTimeout: () {
        mobileAdsInitialized.removeListener(listener);
        return false;
      });
    } catch (_) {
      mobileAdsInitialized.removeListener(listener);
      return false;
    }
  }

  // ── App Open Ad ────────────────────────────────────────────────
  Future<void> loadAppOpenAd() async {
    if (!await _ensureMobileAdsReady()) return;
    if (_appOpenAd != null) return;
    await AppOpenAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
        },
        onAdFailedToLoad: (_) {
          _appOpenAd = null;
        },
      ),
    );
  }

  void showAppOpenAdIfAvailable() {
    if (_appOpenAd == null || _isAppOpenAdShowing) return;
    _isAppOpenAdShowing = true;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        AnalyticsService.instance.logAdImpression(
          adUnit: interstitialId,
          adFormat: 'app_open',
        );
      },
      onAdDismissedFullScreenContent: (ad) {
        _isAppOpenAdShowing = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        _isAppOpenAdShowing = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
    );

    _appOpenAd!.show();
  }

  // ── Interstitial ─────────────────────────────────────────────
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;
  bool _isInterstitialLoading = false;
  DateTime? _lastInterstitialShownAt;
  static const Duration _interstitialCooldown = Duration(minutes: 2);

  Future<void> loadInterstitialAd() async {
    print("load Ads123 loadInterstitialAd");
  
    if (!await _ensureMobileAdsReady()) return;
    if (_isInterstitialReady || _isInterstitialLoading) return;
    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
          _isInterstitialLoading = false;
        },
        onAdFailedToLoad: (_) {
          _interstitialAd = null;
          _isInterstitialReady = false;
          _isInterstitialLoading = false;
        },
      ),
    );
  }

  void showInterstititalAd(BuildContext context, {VoidCallback? onRoute}) {
    print("show Ads123 showInterstititalAd");
    
    final now = DateTime.now();
    if (_lastInterstitialShownAt != null &&
        now.difference(_lastInterstitialShownAt!) < _interstitialCooldown) {
      // Frequency cap: don't show and don't trigger new load.
      onRoute?.call();
      return;
    }

    if (!_isInterstitialReady || _interstitialAd == null) {
      loadInterstitialAd();
      onRoute?.call();
      return;
    }

    _interstitialAd!
      ..fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) {
          _lastInterstitialShownAt = DateTime.now();
        },
        onAdDismissedFullScreenContent: (_) {
          _isInterstitialReady = false;
          AnalyticsService.instance.logInterstitialShown(adUnit: interstitialId);
          _interstitialAd?.dispose();
          _interstitialAd = null;
          // Reload ONLY after it was shown/dismissed.
          loadInterstitialAd();
          onRoute?.call();
        },
        onAdFailedToShowFullScreenContent: (_, __) {
          _isInterstitialReady = false;
          _interstitialAd?.dispose();
          _interstitialAd = null;
          // Do not reload here; next show attempt will trigger a load.
          onRoute?.call(); // fallback
        },
      )
      ..show();
  }

  // ── Rewarded ─────────────────────────────────────────────────
  RewardedAd? _rewardedAd;
  bool _isRewardedReady = false;
  bool _isRewardedLoading = false;

  Future<void> loadRewardedAd() async {
    print("load Ads123 RewardedAd");
    if (!await _ensureMobileAdsReady()) return;
    if (_isRewardedReady || _isRewardedLoading) return;
    _isRewardedLoading = true;
    RewardedAd.load(
      adUnitId: rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedReady = true;
          _isRewardedLoading = false;
        },
        onAdFailedToLoad: (_) {
          _rewardedAd = null;
          _isRewardedReady = false;
          _isRewardedLoading = false;
        },
      ),
    );
  }

  /// Shows a confirmation dialog, then plays rewarded ad.
  /// If the ad is unavailable, calls [onRewardGranted] directly (no blocking).
  void showRewardedAd(
    BuildContext context, {
    required VoidCallback onRewardGranted,
  }) {
    print("show Ads123 showRewardedAd");
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(ctx.responsiveSize(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B1A3A), Color(0xFF102C5A)],
            ),
            border: Border.all(
              color: const Color(0xFFFFD36A).withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(ctx.responsiveSize(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox(width: ctx.responsiveSize(24)),
                    Expanded(
                      child: Text(
                        DivineReward[selectedLanguage],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: ctx.responsiveFontSize(22),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFFD36A),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(Icons.close,
                          color: Colors.white70,
                          size: ctx.responsiveSize(24)),
                    ),
                  ],
                ),
                SizedBox(height: ctx.responsiveSize(12)),
                Text(
                  RewardedAdsDes[selectedLanguage],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: ctx.responsiveFontSize(15),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: ctx.responsiveSize(20)),
                // Watch & Unlock button
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRewardedAdInternal(context, onRewardGranted: onRewardGranted);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: ctx.responsiveSize(14)),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD36A), Color(0xFFFFB700)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD36A).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_circle_fill, color: Color(0xFF0B1A3A)),
                        const SizedBox(width: 8),
                        Text(
                          WatchUnlock[selectedLanguage],
                          style: TextStyle(
                            fontSize: ctx.responsiveFontSize(18),
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0B1A3A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: ctx.responsiveSize(10)),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    MaybeLater[selectedLanguage],
                    style: const TextStyle(color: Colors.white60),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRewardedAdInternal(
    BuildContext context, {
    required VoidCallback onRewardGranted,
  }) {
    if (!_isRewardedReady || _rewardedAd == null) {
      // Ad not ready — grant access anyway so user isn't blocked
      loadRewardedAd();
      onRewardGranted();
      return;
    }

    _rewardedAd!
      ..fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (_) {
          _isRewardedReady = false;
          _rewardedAd?.dispose();
          _rewardedAd = null;
          // Reload ONLY after it was shown/dismissed.
          loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (_, __) {
          _isRewardedReady = false;
          _rewardedAd?.dispose();
          _rewardedAd = null;
          // Do not reload here; next attempt will trigger a load.
          onRewardGranted(); // fallback
        },
      )
      ..show(onUserEarnedReward: (_, reward) {
        AnalyticsService.instance.logRewardedAdEarned(
          adUnit: rewardedId,
          rewardAmount: reward.amount,
          rewardType: reward.type,
        );
        onRewardGranted();
      });
  }

  // ── Banner (single instance) ───────────────────────────────────
  BannerAd? _bannerAd;
  bool _isBannerLoading = false;
  final ValueNotifier<bool> bannerLoaded = ValueNotifier<bool>(false);

  BannerAd? get bannerAd => _bannerAd;

  Future<void> loadBannerAdOnce() async {
    print("load Ads123 loadBannerAdOnce");
    
    if (!await _ensureMobileAdsReady()) return;
    if (bannerLoaded.value || _isBannerLoading || _bannerAd != null) return;
    _isBannerLoading = true;
    _bannerAd = BannerAd(
      adUnitId: bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          bannerLoaded.value = true;
          _isBannerLoading = false;
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _bannerAd = null;
          bannerLoaded.value = false;
          _isBannerLoading = false;
        },
      ),
    )..load();
  }

  // ── Consent ───────────────────────────────────────────────────
  void _getUserConsent() {
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          _loadConsentForm();
        }
      },
      (_) {},
    );
  }

  void _loadConsentForm() {
    ConsentForm.loadConsentForm(
      (form) async {
        final status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          form.show((_) => _loadConsentForm());
        }
      },
      (_) {},
    );
  }

  void showAdNotReady(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(NoAds[selectedLanguage], textAlign: TextAlign.center),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _appOpenAd?.dispose();
    _bannerAd?.dispose();
  }
}

// ── Banner Widget ─────────────────────────────────────────────────
class AdsBannerWidget extends StatefulWidget {
  final double size;
  const AdsBannerWidget({super.key, this.size = 0.0});

  @override
  State<AdsBannerWidget> createState() => _AdsBannerWidgetState();
}

class _AdsBannerWidgetState extends State<AdsBannerWidget> {

  BannerAd? _bannerAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();

    _bannerAd = BannerAd(
      adUnitId: bannerAdId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    if (!_loaded || _bannerAd == null) {
      return const SizedBox();
    }

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
