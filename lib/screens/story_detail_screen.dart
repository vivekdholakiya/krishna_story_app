import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:krishna_stories_app/services/analytics_service.dart';
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

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  late FlutterTts _tts;

  bool _isFavorite = false;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isTtsReady = false;
  bool _showMoral = false;

  static const double _speechRate = 0.4;
  Duration _elapsed = Duration.zero;
  Duration _totalEstimated = Duration.zero;
  DateTime? _speakStart;
  Timer? _progressTimer;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initTts();
    _checkFav();
    _totalEstimated = _estimateDuration(_removeMoral(widget.content), _speechRate);

    AnalyticsService.instance.logScreenView(
      screenName: 'StoryDetail',
      screenClass: 'StoryDetailScreen',
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _stopTimer();
    _scrollController.dispose();
    super.dispose();
  }

  // ── TTS ────────────────────────────────────────────────────────
  Future<void> _initTts() async {
    _tts = FlutterTts();
    final voices = await _tts.getVoices as List<dynamic>;

    final langMap = {
      'en': 'en-IN',
      'gu': 'gu-IN',
      'hu': 'hi-IN',
      'sa': 'hi-IN',
    };
    final ttsLang = langMap[selectedLanguage] ?? 'en-IN';
    await _tts.setLanguage(ttsLang);

    // Pick best available voice
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
      _speakStart = DateTime.now();
      _elapsed = Duration.zero;
      _startTimer();
      if (mounted) setState(() { _isLoading = false; _isPlaying = true; });
    });
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      _stopTimer();
      setState(() {
        _isPlaying = false;
        _speakStart = null;
        if (_totalEstimated > Duration.zero) _elapsed = _totalEstimated;
      });
    });
    _tts.setErrorHandler((_) {
      if (!mounted) return;
      _stopTimer();
      setState(() { _isPlaying = false; _speakStart = null; });
    });

    if (mounted) setState(() => _isTtsReady = true);
  }

  Future<void> _toggleTts() async {
    if (!_isTtsReady) return;
    if (_isPlaying) {
      await _tts.stop();
      _stopTimer();
      setState(() { _isPlaying = false; _isLoading = false; });
    } else {
      setState(() { _isLoading = true; _isPlaying = false; });
      try {
        await _tts.speak('${_removeMoral(widget.content)} ${JayShreeKrishna[selectedLanguage]}');
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _isLoading && !_isPlaying) setState(() => _isLoading = false);
        });
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _startTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_speakStart == null || !mounted) return;
      setState(() => _elapsed = DateTime.now().difference(_speakStart!));
    });
  }

  void _stopTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  Duration _estimateDuration(String text, double rate) {
    final words = text.split(RegExp(r'\s+')).length;
    final wpm = (120 + rate * 200).round();
    return Duration(seconds: (words / wpm * 60).ceil());
  }

  String _removeMoral(String text) => text.replaceAll(
      RegExp(r'\n*\s*\[moral\][\s\S]*?\[\/moral\]\s*\n*', caseSensitive: false),
      '\n').trim();

  String _extractMoral(String text) {
    final m = RegExp(r'\[moral\]([\s\S]*?)\[\/moral\]', caseSensitive: false).firstMatch(text);
    return m?.group(1)?.trim() ?? '';
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  // ── Favorites ─────────────────────────────────────────────────
  Future<void> _checkFav() async {
    final fav = await FavoriteService.isFavorite(widget.storyKey);
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFav() async {
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
      // Positive engagement trigger
      await ReviewService().incrementEngagement(triggerIfEligible: true);
    }
    if (mounted) setState(() => _isFavorite = !_isFavorite);
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final moral = _extractMoral(widget.content);
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(context.responsiveSize(16)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: _iconBox(
                child: Icon(Icons.arrow_back,
                    color: Colors.white, size: context.responsiveSize(24))),
          ),
          SizedBox(width: context.responsiveSize(12)),
          Expanded(
            child: Text(widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: context.responsiveFontSize(20),
                    fontWeight: FontWeight.bold)),
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
                  Text(widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: context.responsiveFontSize(22),
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const Divider(color: Color(0xFFFFD36A)),
                  Text(_removeMoral(widget.content),
                      textAlign: TextAlign.justify,
                      style: TextStyle(
                          fontSize: context.responsiveFontSize(17),
                          height: 1.7,
                          color: Colors.white)),
                  Text('\n${JayShreeKrishna[selectedLanguage]} 🙏',
                      style: TextStyle(
                          color: const Color(0xFFFFD36A),
                          fontSize: context.responsiveFontSize(18))),
                  if (moral.isNotEmpty) _buildMoralSection(moral),
                ],
              ),
            ),
          ),
          _buildTtsBar(),
        ],
      ),
    );
  }

  Widget _buildMoralSection(String moral) {
    return Column(
      children: [
        TextButton(
          onPressed: () {
            setState(() => _showMoral = !_showMoral);
            if (_showMoral) {
              ReviewService().incrementEngagement(triggerIfEligible: true);
            }
          },
          child: Text(
            _showMoral ? HideMoral[selectedLanguage] : ViewMoral[selectedLanguage],
            style: const TextStyle(color: Color(0xFFFFD36A)),
          ),
        ),
        AnimatedCrossFade(
          crossFadeState:
              _showMoral ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(context.responsiveSize(16)),
            ),
            child: Text(moral,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: context.responsiveFontSize(16))),
          ),
        ),
      ],
    );
  }

  Widget _buildTtsBar() {
    final progress = _totalEstimated.inMilliseconds == 0
        ? 0.0
        : (_elapsed.inMilliseconds / _totalEstimated.inMilliseconds).clamp(0.0, 1.0);
    final timeLabel = _fmt(_elapsed) == _fmt(_totalEstimated) ? '00:00' : _fmt(_elapsed);

    return Row(
      children: [
        if (_isLoading)
          SizedBox(
            width: context.responsiveSize(36),
            height: context.responsiveSize(36),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(Color(0xFFFFD36A)),
            ),
          )
        else
          GestureDetector(
            onTap: _isLoading ? null : _toggleTts,
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: const Color(0xFFFFD36A),
              size: context.responsiveSize(36),
            ),
          ),
        Expanded(
          child: Slider(
            value: progress,
            onChanged: null,
            activeColor: const Color(0xFFFFD36A),
            inactiveColor: Colors.white30,
          ),
        ),
        Text(timeLabel,
            style: TextStyle(
                color: Colors.white70,
                fontSize: context.responsiveFontSize(12))),
      ],
    );
  }
}
