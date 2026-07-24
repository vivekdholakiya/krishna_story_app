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
  appOpenId: openAdId,
  nativeAdId: nativeAdId,
);

class AdsControllerMain with WidgetsBindingObserver {
  static final ValueNotifier<bool> mobileAdsInitialized = ValueNotifier<bool>(false);

  static void markMobileAdsInitialized() {
    if (!mobileAdsInitialized.value) mobileAdsInitialized.value = true;
  }

  final String interstitialId;
  final String rewardedId;
  final String bannerId;
  final String appOpenId;
  final String nativeAdId;

  AdsControllerMain({
    required this.interstitialId,
    required this.rewardedId,
    required this.bannerId,
    required this.appOpenId,
    required this.nativeAdId,
  }) {
    _getUserConsent();
    // Lifecycle observer for App Open ads — attached here so nothing needs
    // to change in main.dart beyond referencing `adsControllerVar` once.
    WidgetsBinding.instance.addObserver(this);
    // Preload the very first App Open ad as early as possible.
    loadAppOpenAd();
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

  // ── Cross-format full-screen-ad lock ───────────────────────────
  // `adShowed == true` means "no full-screen ad is currently on screen" —
  // every full-screen format (App Open, Interstitial, Rewarded) reads this
  // before showing and sets it while it's up, so they never overlap.
  bool adShowed = true;
  DateTime? _lastFullScreenAdShownAt;
  static const Duration _crossFormatGap = Duration(seconds: 60);

  bool get _canShowAnyFullScreenAd {
    if (!adShowed) return false; // something is already showing
    if (_lastFullScreenAdShownAt == null) return true;
    return DateTime.now().difference(_lastFullScreenAdShownAt!) >= _crossFormatGap;
  }

  // ── App Open Ad ────────────────────────────────────────────────
  AppOpenAd? appOpenAd;
  bool _isLoadingAppOpenAd = false;
  DateTime? _appOpenLoadedAt;
  DateTime? _lastAppOpenShownAt;
  bool _isAppOpenAdShowing = false;
  bool _hasHadFirstResume = false;
  int _appOpenLoadAttempts = 0;

  /// Google recommends not showing a cached App Open ad once it's older
  /// than ~4 hours.
  static const Duration _appOpenMaxAge = Duration(hours: 4);

  /// Minimum time between two App Open ad impressions.
  static const Duration appOpenCooldown = Duration(hours: 4);

  bool get _isAppOpenAdExpired {
    if (_appOpenLoadedAt == null) return true;
    return DateTime.now().difference(_appOpenLoadedAt!) > _appOpenMaxAge;
  }

  bool get _isAppOpenAdAvailable => appOpenAd != null && !_isAppOpenAdExpired;

  Future<void> loadAppOpenAd() async {
    if (!await _ensureMobileAdsReady()) return;
    if (_isLoadingAppOpenAd || _isAppOpenAdAvailable) return;
    _isLoadingAppOpenAd = true;

    try {
      await AppOpenAd.load(
        adUnitId: appOpenId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _isLoadingAppOpenAd = false;
            _appOpenLoadAttempts = 0;
            appOpenAd = ad;
            _appOpenLoadedAt = DateTime.now();
          },
          onAdFailedToLoad: (error) {
            _isLoadingAppOpenAd = false;
            appOpenAd = null;
            _appOpenLoadAttempts++;
            // Gentle backoff instead of hammering the network on repeated
            // no-fill/no-internet failures.
            final delaySeconds = [30, 60, 120, 300][
                (_appOpenLoadAttempts - 1).clamp(0, 3)];
            Future.delayed(Duration(seconds: delaySeconds), () {
              if (!_isAppOpenAdAvailable) loadAppOpenAd();
            });
          },
        ),
      );
    } catch (_) {
      _isLoadingAppOpenAd = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // The very first "resumed" event fires right after cold start — that
    // moment belongs to the splash screen, not an App Open ad. Only show
    // on genuine background -> foreground transitions.
    if (!_hasHadFirstResume) {
      _hasHadFirstResume = true;
      return;
    }
    showOpenAdIfEligible();
  }

  /// Shows the cached App Open ad only if every rule allows it. Safe to
  /// call speculatively — it silently no-ops when conditions aren't met.
  void showOpenAdIfEligible() {
    if (_isAppOpenAdShowing) return; // never show two at once

    if (!_isAppOpenAdAvailable) {
      loadAppOpenAd();
      return;
    }

    if (_lastAppOpenShownAt != null &&
        DateTime.now().difference(_lastAppOpenShownAt!) < appOpenCooldown) {
      return; // respect the cooldown between impressions
    }

    if (!_canShowAnyFullScreenAd) {
      return; // an Interstitial/Rewarded ad is showing or just closed
    }

    _isAppOpenAdShowing = true;
    appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        adShowed = false;
        _lastFullScreenAdShownAt = DateTime.now();
      },
      onAdDismissedFullScreenContent: (ad) {
        _isAppOpenAdShowing = false;
        adShowed = true;
        _lastAppOpenShownAt = DateTime.now();
        ad.dispose();
        appOpenAd = null;
        loadAppOpenAd(); // always preload the next one right away
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isAppOpenAdShowing = false;
        adShowed = true;
        ad.dispose();
        appOpenAd = null;
        loadAppOpenAd();
      },
    );
    appOpenAd!.show();
  }

  // ── Interstitial ─────────────────────────────────────────────
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;
  bool _isInterstitialLoading = false;
  DateTime? _lastInterstitialShownAt;
  static const Duration _interstitialCooldown = Duration(minutes: 2);

  Future<void> loadInterstitialAd() async {
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
    final now = DateTime.now();

    if (_lastInterstitialShownAt != null &&
        now.difference(_lastInterstitialShownAt!) < _interstitialCooldown) {
      // Frequency cap: don't show and don't trigger new load.
      onRoute?.call();
      return;
    }

    // Cross-format guard: never overlap App Open/Rewarded, never show
    // within 60s of another full-screen ad (e.g. right after App Open).
    if (!_canShowAnyFullScreenAd) {
      onRoute?.call();
      return;
    }

    if (_interstitialAd == null) {
      adShowed = true;
      loadInterstitialAd();
      onRoute?.call();
      return;
    }

    _interstitialAd
      ?..fullScreenContentCallback = FullScreenContentCallback(
          onAdShowedFullScreenContent: (ad) {
            adShowed = false;
            _lastInterstitialShownAt = DateTime.now();
            _lastFullScreenAdShownAt = DateTime.now();
            onRoute?.call();
          },
          onAdDismissedFullScreenContent: (ad) async {
            adShowed = true;
            AnalyticsService.instance.logInterstitialShown(adUnit: interstitialId);
            _interstitialAd?.dispose();
            _interstitialAd = null;
            // Reload ONLY after it was shown/dismissed.
            loadInterstitialAd();
          },
          onAdFailedToShowFullScreenContent: (ad, error) async {
            adShowed = true;
            _interstitialAd?.dispose();
            _interstitialAd = null;
            onRoute?.call();
            // Do not reload here; next show attempt will trigger a load.
          })
      ..show();
  }

  // ── Rewarded ─────────────────────────────────────────────────
  RewardedAd? _rewardedAd;
  bool _isRewardedReady = false;
  bool _isRewardedLoading = false;

  Future<void> loadRewardedAd() async {
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
      adShowed = true;
      // Ad not ready — grant access anyway so user isn't blocked
      loadRewardedAd();
      onRewardGranted();
      return;
    }

    // Cross-format guard: extremely rare (App Open showing at the exact
    // moment the user tapped "watch ad"). Since the user explicitly asked
    // for this reward, never leave them blocked — grant it directly.
    if (!_canShowAnyFullScreenAd) {
      onRewardGranted();
      return;
    }

    _rewardedAd!
      ..fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          adShowed = false;
          _lastFullScreenAdShownAt = DateTime.now();
        },
        onAdDismissedFullScreenContent: (_) {
          adShowed = true;
          _isRewardedReady = false;
          _rewardedAd?.dispose();
          _rewardedAd = null;
          // Reload ONLY after it was shown/dismissed.
          loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (_, __) {
          adShowed = true;
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
    WidgetsBinding.instance.removeObserver(this);
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    appOpenAd?.dispose();
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

// ── Native Ad Widget ────────────────────────────────────────────────
enum NativeAdTemplateType { small, medium }

/// A reusable, self-contained Native Ad. Drop it into a `ListView`, an
/// article page, or between content sections — it manages its own
/// load/loading/error state and disposes its `NativeAd` correctly.
class NativeAdWidget extends StatefulWidget {
  final NativeAdTemplateType templateType;
  final double? height;
  final EdgeInsetsGeometry margin;
  final BorderRadiusGeometry borderRadius;
  final Color? backgroundColor;

  /// Optional custom loading placeholder. Defaults to a subtle container
  /// with a small spinner.
  final WidgetBuilder? loadingBuilder;

  /// Optional custom "failed to load" placeholder. Defaults to collapsing
  /// to nothing so a failed ad never leaves a visible gap in your layout.
  final WidgetBuilder? errorBuilder;

  const NativeAdWidget({
    super.key,
    this.templateType = NativeAdTemplateType.medium,
    this.height,
    this.margin = const EdgeInsets.symmetric(vertical: 10),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.backgroundColor,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    NativeAd(
      adUnitId: nativeAdId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: widget.templateType == NativeAdTemplateType.small
            ? TemplateType.small
            : TemplateType.medium,
        mainBackgroundColor: widget.backgroundColor ?? Colors.transparent,
        cornerRadius: 16,
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose(); // widget was removed before the ad came back
            return;
          }
          setState(() {
            _nativeAd = ad as NativeAd;
            _isLoaded = true;
            _failed = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _nativeAd = null;
            _isLoaded = false;
            _failed = true;
          });
        },
      ),
    ).load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  double get _defaultHeight =>
      widget.templateType == NativeAdTemplateType.small ? 100 : 320;

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      // Fail silently: never leave a broken box in the middle of content.
      return widget.errorBuilder?.call(context) ?? const SizedBox.shrink();
    }

    if (!_isLoaded || _nativeAd == null) {
      return widget.loadingBuilder?.call(context) ?? _defaultLoadingPlaceholder();
    }

    return Container(
      height: widget.height ?? _defaultHeight,
      margin: widget.margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: widget.borderRadius),
      child: AdWidget(ad: _nativeAd!),
    );
  }

  Widget _defaultLoadingPlaceholder() {
    return Container(
      height: widget.height ?? _defaultHeight,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: widget.borderRadius,
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
