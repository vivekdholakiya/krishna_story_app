

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:krishna_stories_app/services/analytics_service.dart';
import 'package:krishna_stories_app/services/audio_analytics.dart';
import 'package:krishna_stories_app/services/audio_manifest.dart';
import 'package:krishna_stories_app/services/audio_service.dart';
import 'package:krishna_stories_app/services/context_extensions.dart';
import 'package:krishna_stories_app/services/review_service.dart';
import '../services/app_text_data.dart';
import '../services/favorite_service.dart';
import '../services/util.dart';
import '../widgets/app_background.dart';

class StoryDetailScreen extends StatefulWidget {
  final String title;
  final String content;
  final List<Color> colors;
  final String storyKey;
  final int categoryIndex;
  final int storyIndex;
  final String categoryName;

  const StoryDetailScreen({
    super.key,
    required this.title,
    required this.content,
    required this.colors,
    required this.storyKey,
    required this.categoryIndex,
    required this.storyIndex,
    required this.categoryName,
  });

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen>
    with WidgetsBindingObserver {
  // ── Audio (just_audio + TTS fallback) ────────────────────────
  final AudioPlayer _player = AudioPlayer();

  // TTS — used only when no Sarvam audio is available
  late FlutterTts _tts;
  bool _isTtsReady = false;
  bool _usingTts = false;
  static const double _speechRate = 0.4;
  Duration _ttsEstimated = Duration.zero;
  DateTime? _ttsStartTime;
  Timer? _ttsProgressTimer;

  bool _isFavorite = false;
  bool _isPlaying = false;

  /// True while we are fetching/buffering the audio file.
  bool _isLoading = false;

  bool _showMoral = false;
  final GlobalKey _moralKey = GlobalKey(); // ADD THIS

  /// Preloaded file — fetched silently when the screen opens.
  File? _preloadedFile;
  bool _preloadDone = false;

  late final AudioAnalytics _audioAnalytics;
  DateTime? _playTapTime;
  bool _lastFetchWasCacheHit = false;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<ProcessingState>? _processingStateSub;

  Duration _elapsed = Duration.zero;
  Duration _totalDuration = Duration.zero;

  final ScrollController _scrollController = ScrollController();
  final Set<int> _scrollMilestonesReached = {};

  // ── Life-cycle ────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _audioAnalytics = AudioAnalytics(
      storyKey: widget.storyKey,
      categoryId: widget.categoryIndex + 1,
      storyIndex: widget.storyIndex + 1,
      lang: selectedLanguage,
      voice: AudioManifest.instance.entryFor(widget.storyKey)?.voice ?? '',
      playbackMode: AudioManifest.instance.hasEntry(widget.storyKey)
          ? 'sarvam'
          : 'tts_fallback',
    );

    _initTts();
    _initPlayerStreams();
    _preloadAudio();   // ← background preload as soon as screen opens
    _checkFav();
    _scrollController.addListener(_onScroll);

    AnalyticsService.instance.logScreenView(
      screenName: 'StoryDetail',
      screenClass: 'StoryDetailScreen',
    );
  }

  /// Stop audio whenever the app goes to background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopAudio();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Fire 'skipped' analytics if user left mid-playback.
    if (_isPlaying) {
      _audioAnalytics.skipped(
        positionSec: _player.position.inSeconds,
        durationSec: _totalDuration.inSeconds,
      );
    }

    _stopAudio(dispose: true);

    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _processingStateSub?.cancel();
    _player.dispose();
    _tts.stop();
    _ttsProgressTimer?.cancel();

    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    super.dispose();
  }

  // ── Background preload ────────────────────────────────────────
  /// Silently downloads/caches the audio file the moment the screen opens.
  /// No loading indicator shown — this runs quietly in the background.
  /// When the user taps Play, [_loadAndPlay] finds the file already cached.
  Future<void> _preloadAudio() async {
    if (!AudioManifest.instance.hasEntry(widget.storyKey)) return;
    try {
      _preloadedFile = await AudioService.instance.getAudio(
        widget.storyKey,
        onCacheHit: (hit) => _lastFetchWasCacheHit = hit,
      );
    } catch (_) {
      _preloadedFile = null;
    } finally {
      _preloadDone = true;
    }
  }

  // ── TTS init ──────────────────────────────────────────────────
  Future<void> _initTts() async {
    _tts = FlutterTts();
    final voices = await _tts.getVoices as List<dynamic>;
    final langMap = {'en': 'en-IN', 'gu': 'gu-IN', 'hi': 'hi-IN', 'sa': 'hi-IN'};
    final ttsLang = langMap[selectedLanguage] ?? 'en-IN';
    await _tts.setLanguage(ttsLang);

    final preferred = voices.firstWhere(
          (v) =>
      (v['locale'] ?? '').startsWith(ttsLang) &&
          ((v['name'] ?? '').toLowerCase().contains('wavenet') ||
              (v['name'] ?? '').toLowerCase().contains('neural') ||
              (v['name'] ?? '').toLowerCase().contains('chirp')),
      orElse: () => voices.firstWhere(
            (v) => (v['locale'] ?? '').startsWith(ttsLang),
        orElse: () => {'name': ''},
      ),
    );
    final voiceName = preferred['name'] as String? ?? '';
    if (voiceName.isNotEmpty) await _tts.setVoice({'name': voiceName});

    await _tts.setSpeechRate(_speechRate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(0.95);

    _tts.setStartHandler(() {
      _ttsStartTime = DateTime.now();
      _startTtsTimer();
      if (mounted) setState(() { _isLoading = false; _isPlaying = true; });
    });

    _tts.setCompletionHandler(() {
      if (!mounted) return;
      _ttsProgressTimer?.cancel();
      _audioAnalytics.completed(durationSec: _ttsEstimated.inSeconds);
      setState(() {
        _isPlaying = false;
        _elapsed = _ttsEstimated;
        _ttsStartTime = null;
      });
    });

    _tts.setErrorHandler((_) {
      if (!mounted) return;
      _ttsProgressTimer?.cancel();
      setState(() { _isPlaying = false; _isLoading = false; _ttsStartTime = null; });
    });

    if (mounted) setState(() => _isTtsReady = true);
  }

  void _startTtsTimer() {
    _ttsProgressTimer?.cancel();
    _ttsProgressTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_ttsStartTime == null || !mounted) return;
      setState(() => _elapsed = DateTime.now().difference(_ttsStartTime!));
    });
  }

  Duration _estimateTtsDuration(String text) {
    final words = text.split(RegExp(r'\s+')).length;
    final wpm = (120 + _speechRate * 200).round();
    return Duration(seconds: (words / wpm * 60).ceil());
  }

  // ── Player stream wiring ──────────────────────────────────────
  void _initPlayerStreams() {
    // Duration (total length) stream
    _durSub = _player.durationStream.listen((d) {
      if (d != null && mounted) {
        setState(() => _totalDuration = d);
      }
    });

    // Position (progress) stream
    _posSub = _player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _elapsed = pos);
      if (_totalDuration.inSeconds > 0) {
        _audioAnalytics.onProgress(
          positionSec: pos.inSeconds,
          durationSec: _totalDuration.inSeconds,
        );
      }
    });

    // PlayerState stream — maps buffering → loading indicator, completed → reset
    _stateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;

      final isBuffering =
          state.processingState == ProcessingState.buffering ||
              state.processingState == ProcessingState.loading;

      final isCompleted =
          state.processingState == ProcessingState.completed;

      if (isCompleted) {
        _audioAnalytics.completed(durationSec: _totalDuration.inSeconds);
        _player.seek(Duration.zero);
        _player.pause();
        setState(() {
          _isPlaying = false;
          _isLoading = false;
          _elapsed = _totalDuration;
        });
        return;
      }

      setState(() {
        // Show spinner while the player is buffering/loading internally
        _isLoading = isBuffering && state.playing;
        _isPlaying = state.playing && !isBuffering;
      });
    });
  }

  // ── Playback control ──────────────────────────────────────────

  /// Main toggle: play → pause, pause/stopped → start.
  Future<void> _togglePlayback() async {
    if (_isLoading) return;

    if (_isPlaying) {
      final pos = _usingTts ? _elapsed : _player.position;
      _audioAnalytics.paused(positionSec: pos.inSeconds);
      if (_usingTts) {
        await _tts.stop();
        _ttsProgressTimer?.cancel();
      } else {
        await _player.pause();
      }
      if (mounted) setState(() { _isPlaying = false; _isLoading = false; });
      return;
    }

    // Resume from paused just_audio
    if (!_usingTts &&
        _player.processingState == ProcessingState.ready &&
        _player.position > Duration.zero &&
        _player.position < _totalDuration) {
      _audioAnalytics.resumed(positionSec: _player.position.inSeconds);
      await _player.play();
      return;
    }

    await _startPlayback();
  }

  Future<void> _startPlayback() async {
    _audioAnalytics.playTapped();
    _playTapTime = DateTime.now();
    if (mounted) setState(() { _isLoading = true; _isPlaying = false; });

    final entry = AudioManifest.instance.entryFor(widget.storyKey);
    if (entry == null) {
      // No Sarvam audio — fall back to TTS
      _audioAnalytics.ttsFallbackUsed(reason: 'no_manifest_entry');
      await _speakWithTts();
      return;
    }

    await _loadAndPlay();
  }

  Future<void> _loadAndPlay() async {
    final downloadStart = DateTime.now();

    File? file;

    // Use the preloaded file if available — no download wait for the user.
    if (_preloadDone && _preloadedFile != null) {
      file = _preloadedFile;
      // Already cached — mark as cache hit so analytics are correct.
      _lastFetchWasCacheHit = true;
    } else {
      // Preload not done yet (slow network) — fetch now with spinner showing.
      _audioAnalytics.downloadStarted();
      try {
        file = await AudioService.instance.getAudio(
          widget.storyKey,
          onCacheHit: (hit) => _lastFetchWasCacheHit = hit,
        );
      } catch (_) {
        file = null;
      }
    }

    if (file == null) {
      _audioAnalytics.downloadFailed(
        errorType: 'fetch_failed',
        errorDetail: 'getAudio returned null',
      );
      if (mounted) setState(() => _isLoading = false);
      _showErrorSnackbar();
      return;
    }

    if (!_lastFetchWasCacheHit) {
      try {
        _audioAnalytics.downloadSucceeded(
          bytes: await file.length(),
          durationMs: DateTime.now().difference(downloadStart).inMilliseconds,
        );
      } catch (_) {}
    }

    try {
      // setFilePath triggers ProcessingState.loading → buffering → ready
      await _player.setFilePath(file.path);
      await _player.play();

      if (mounted) {
        _audioAnalytics.started(
          timeToPlayMs:
          DateTime.now().difference(_playTapTime!).inMilliseconds,
          cacheHit: _lastFetchWasCacheHit,
        );
        // _isLoading / _isPlaying are driven by playerStateStream from here.
      }
    } catch (e) {
      _audioAnalytics.downloadFailed(
        errorType: 'playback_failed',
        errorDetail: e.toString(),
      );
      if (mounted) setState(() { _isLoading = false; _isPlaying = false; });
      _showErrorSnackbar();
    }
  }

  Future<void> _speakWithTts() async {
    _usingTts = true;
    final text = _removeMoral(widget.content);
    _ttsEstimated = _estimateTtsDuration(text);
    if (mounted) setState(() => _totalDuration = _ttsEstimated);

    if (!_isTtsReady) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _elapsed = Duration.zero;
    try {
      await _tts.speak('$text ${JayShreeKrishna[selectedLanguage]}');
      // _isLoading → false and _isPlaying → true are set in TTS setStartHandler
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _isLoading && !_isPlaying) {
          setState(() => _isLoading = false);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Stops audio cleanly. Pass [dispose: true] from dispose() to skip setState.
  Future<void> _stopAudio({bool dispose = false}) async {
    if (_usingTts) {
      await _tts.stop();
      _ttsProgressTimer?.cancel();
    } else {
      await _player.stop();
    }
    if (!dispose && mounted) {
      setState(() { _isPlaying = false; _isLoading = false; });
    }
  }

  // ── Snackbars ─────────────────────────────────────────────────
  void _showErrorSnackbar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not load audio. Please try again.')),
    );
  }

  // ── Scroll analytics ─────────────────────────────────────────
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    final pct = (_scrollController.offset / max * 100).clamp(0, 100).toInt();
    for (final milestone in [25, 50, 75, 100]) {
      if (pct >= milestone && !_scrollMilestonesReached.contains(milestone)) {
        _scrollMilestonesReached.add(milestone);
        AnalyticsService.instance.logStoryScroll(
          storyKey: widget.storyKey,
          categoryIndex: widget.categoryIndex,
          storyIndex: widget.storyIndex,
          lang: selectedLanguage,
          milestone: milestone,
        );
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────
  String _removeMoral(String text) => text
      .replaceAll(
    RegExp(r'\n*\s*\[moral\][\s\S]*?\[\/moral\]\s*\n*',
        caseSensitive: false),
    '\n',
  )
      .trim();

  String _extractMoral(String text) {
    final m = RegExp(r'\[moral\]([\s\S]*?)\[\/moral\]', caseSensitive: false)
        .firstMatch(text);
    return m?.group(1)?.trim() ?? '';
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:'
          '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  // ── Favorites ─────────────────────────────────────────────────
  Future<void> _checkFav() async {
    final fav = await FavoriteService.isFavorite(widget.storyKey);
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFav() async {
    final willAdd = !_isFavorite;
    if (_isFavorite) {
      await FavoriteService.removeFromFavorites(widget.storyKey);
    } else {
      await FavoriteService.addToFavorites(FavoriteStory(
        storyKey: widget.storyKey,
        title: widget.title,
        content: widget.content,
        categoryIndex: widget.categoryIndex,
        storyIndex: widget.storyIndex,
        categoryName: widget.categoryName,
      ));
      await ReviewService().incrementEngagement(triggerIfEligible: true);
    }
    AnalyticsService.instance.logFavoriteToggle(
      storyKey: widget.storyKey,
      categoryIndex: widget.categoryIndex,
      storyIndex: widget.storyIndex,
      lang: selectedLanguage,
      added: willAdd,
    );
    if (mounted) setState(() => _isFavorite = !_isFavorite);
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final moral = _extractMoral(widget.content);
    return PopScope(
      // Stop audio when back button / gesture is used.
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await _stopAudio();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          body: AppBackground(
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildContent(moral)),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: context.responsiveSize(16)),

                  child: _buildAudioBar()),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(context.responsiveSize(16)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              await _stopAudio();          // ← stop before pop
              if (mounted) Navigator.pop(context);
            },
            child: _iconBox(
              child: Icon(Icons.arrow_back,
                  color: Colors.white, size: context.responsiveSize(24)),
            ),
          ),
          SizedBox(width: context.responsiveSize(12)),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: context.responsiveFontSize(20),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GestureDetector(
            onTap: _toggleFav,
            child: _iconBox(
              child: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.redAccent : Colors.white,
                size: context.responsiveSize(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBox({required Widget child}) => Container(
    padding: EdgeInsets.all(context.responsiveSize(10)),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(context.responsiveSize(14)),
    ),
    child: child,
  );

  // ── Content ───────────────────────────────────────────────────
  Widget _buildContent(String moral) {
    return Container(
      margin: EdgeInsets.all(context.responsiveSize(16)),
      padding: EdgeInsets.all(context.responsiveSize(16)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(context.responsiveSize(26)),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  Icon(Icons.auto_stories,
                      size: context.responsiveSize(46),
                      color: const Color(0xFFFFD36A)),
                  SizedBox(height: context.responsiveSize(12)),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: context.responsiveFontSize(22),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Divider(color: Color(0xFFFFD36A)),
                  Text(
                    _removeMoral(widget.content),
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontSize: context.responsiveFontSize(17),
                      height: 1.7,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '\n${JayShreeKrishna[selectedLanguage]} 🙏',
                    style: TextStyle(
                      color: const Color(0xFFFFD36A),
                      fontSize: context.responsiveFontSize(18),
                    ),
                  ),

                  if (moral.isNotEmpty) _buildMoralSection(moral),
                ],
              ),
            ),
          ),
          // _buildAudioBar(),
        ],
      ),
    );
  }

  Widget _buildMoralSection(String moral) {
    return Column(
      children: [
        SizedBox(height: context.responsiveSize(12),),
        /// VIEW / HIDE BUTTON
        Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(
                context.responsiveSize(40),
              ),
              onTap: () {
                setState(() => _showMoral = !_showMoral);

                if (_showMoral) {
                  ReviewService().incrementEngagement(triggerIfEligible: true);

                  // Wait for AnimatedCrossFade to finish expanding, then scroll to bottom
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    }
                  });
                }
              },
              //
              // onTap: () {
              //   setState(() => _showMoral = !_showMoral);
              //
              //   if (_showMoral) {
              //     ReviewService().incrementEngagement(triggerIfEligible: true);
              //
              //     WidgetsBinding.instance.addPostFrameCallback((_) {
              //       if (_scrollController.hasClients) {
              //         _scrollController.jumpTo(
              //           _scrollController.position.maxScrollExtent,
              //         );
              //       }
              //     });
              //   }
              // },

              child: Ink(
                padding: EdgeInsets.symmetric(
                  horizontal: context.responsiveSize(18),
                  vertical: context.responsiveSize(12),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    context.responsiveSize(40),
                  ),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFD36A),
                      Color(0xFFFFB347),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                      const Color(0xFFFFD36A).withOpacity(0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showMoral
                          ? Icons.visibility_off_rounded
                          : Icons.auto_stories_rounded,
                      color: Colors.black,
                      size: context.responsiveSize(20),
                    ),

                    SizedBox(width: context.responsiveSize(8)),

                    Text(

                      _showMoral
                          ? HideMoral[selectedLanguage]
                          : ViewMoral[selectedLanguage],
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: context.responsiveFontSize(14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        SizedBox(height: context.responsiveSize(16)),

        /// MORAL CARD
        AnimatedCrossFade(
          crossFadeState: _showMoral
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 450),
          firstChild: const SizedBox.shrink(),
          secondChild: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(
                context.responsiveSize(20),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  context.responsiveSize(24),
                ),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFD36A).withOpacity(0.18),
                    Colors.white.withOpacity(0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: const Color(0xFFFFD36A)
                      .withOpacity(0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// QUOTE ICON
                  Icon(
                    Icons.format_quote_rounded,
                    color:
                    const Color(0xFFFFD36A).withOpacity(0.7),
                    size: context.responsiveSize(34),
                  ),

                  SizedBox(height: context.responsiveSize(10)),

                  /// MORAL TEXT
                  Text(                      key: _moralKey, // ADD THIS

                    moral,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: context.responsiveFontSize(16),
                      height: 1.7,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Audio bar ─────────────────────────────────────────────────
  Widget _buildAudioBar() {
    final total = _totalDuration.inMilliseconds;

    final progress = total == 0
        ? 0.0
        : (_elapsed.inMilliseconds / total).clamp(0.0, 1.0);

    final elapsedLabel =
    (_elapsed >= _totalDuration && _totalDuration > Duration.zero)
        ? '00:00'
        : _fmt(_elapsed);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      padding: EdgeInsets.all(context.responsiveSize(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          context.responsiveSize(24),
        ),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// CONTROLS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /// BACKWARD
              _audioControlButton(
                icon: Icons.replay_10_rounded,
                onTap: () async {
                  final target =
                      _elapsed - const Duration(seconds: 10);

                  await _player.seek(
                    target < Duration.zero
                        ? Duration.zero
                        : target,
                  );
                },
              ),

              SizedBox(width: context.responsiveSize(16)),

              /// PLAY / PAUSE
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: context.responsiveSize(64),
                height: context.responsiveSize(64),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFD36A),
                      Color(0xFFFFB347),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                      const Color(0xFFFFD36A).withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _isLoading
                    ? Padding(
                  padding: EdgeInsets.all(
                    context.responsiveSize(16),
                  ),
                  child: const CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(
                      Colors.black,
                    ),
                  ),
                )
                    : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: _togglePlayback,
                    child: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: context.responsiveSize(36),
                    ),
                  ),
                ),
              ),

              SizedBox(width: context.responsiveSize(16)),

              /// FORWARD
              _audioControlButton(
                icon: Icons.forward_10_rounded,
                onTap: () async {
                  final target =
                      _elapsed + const Duration(seconds: 10);

                  await _player.seek(target);
                },
              ),
            ],
          ),

          SizedBox(height: context.responsiveSize(20)),

          /// SLIDER
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 7,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 16,
              ),
            ),
            child: Slider(
              value: progress,
              onChanged: _usingTts
                  ? null
                  : (v) async {
                if (_totalDuration == Duration.zero) return;

                final target = Duration(
                  milliseconds: (v * total).round(),
                );

                await _player.seek(target);
              },
              activeColor: const Color(0xFFFFD36A),
              inactiveColor: Colors.white24,
            ),
          ),

          /// TIME
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.responsiveSize(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  elapsedLabel,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: context.responsiveFontSize(11),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _fmt(_totalDuration),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: context.responsiveFontSize(11),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _audioControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Ink(
          width: context.responsiveSize(48),
          height: context.responsiveSize(48),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.08),
            border: Border.all(
              color: Colors.white.withOpacity(0.06),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: context.responsiveSize(24),
          ),
        ),
      ),
    );
  }
}