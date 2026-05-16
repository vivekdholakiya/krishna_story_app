import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krishna_stories_app/services/context_extensions.dart';
import '../services/ads.dart';
import '../services/app_text_data.dart';
import '../services/util.dart';
import '../widgets/app_background.dart';
import 'story_detail_screen.dart';
import '../model/caregory_model.dart';

class StoriesListScreen extends StatefulWidget {
  final StoryCategory category;
  final List<Color> colors;
  final int categoryIndex;
  final Map<String, dynamic> storyDetails;

  const StoriesListScreen({
    super.key,
    required this.category,
    required this.colors,
    required this.categoryIndex,
    required this.storyDetails,
  });

  @override
  State<StoriesListScreen> createState() => _StoriesListScreenState();
}

class _StoriesListScreenState extends State<StoriesListScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _storyKey(int index) {
    final base = '${widget.categoryIndex + 1}.${index + 1}';
    switch (selectedLanguage) {
      case 'gu':  return '$base.1';
      case 'hu':  return '$base.2';
      case 'sa':  return '$base.3';
      default:    return base;
    }
  }

  bool get _isLocked => false; // first 3 free, rest locked — logic below

  void _openStory(int index, String title, String content, String key) {
    void navigate() => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoryDetailScreen(
              title: title,
              content: content,
              colors: widget.colors,
              storyKey: key,
              categoryIndex: widget.categoryIndex,
              storyIndex: index,
              categoryName: widget.category.category,
            ),
          ),
        );

    if (index > 2) {
      adsControllerVar.showRewardedAd(context, onRewardGranted: navigate);
    } else {
      navigate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kStatusBarStyle,
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fade,
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.responsiveSize(18),
                          vertical: context.responsiveSize(12)),
                      itemCount: widget.category.stories.length,
                      itemBuilder: (_, i) {
                        final key = _storyKey(i);
                        final title = widget.category.stories[i];
                        final content = widget.storyDetails[key] ??
                            StoryContentNotAvailable[selectedLanguage];
                        return _buildCard(i, title, content, key);
                      },
                    ),
                  ),
                ),
                SizedBox(height: context.responsiveSize(20)),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const AdsBannerWidget(),
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
            child: Container(
              padding: EdgeInsets.all(context.responsiveSize(10)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(context.responsiveSize(14)),
                border: Border.all(color: const Color(0xFFFFD36A).withOpacity(0.4)),
              ),
              child: Icon(Icons.arrow_back,
                  color: Colors.white, size: context.responsiveSize(24)),
            ),
          ),
          SizedBox(width: context.responsiveSize(14)),
          Expanded(
            child: Text(widget.category.category,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: context.responsiveFontSize(22),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(int index, String title, String content, String key) {
    final locked = index > 2;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + index * 60),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Transform.translate(
          offset: Offset(0, 20 * (1 - v)),
          child: Opacity(opacity: v, child: child)),
      child: GestureDetector(
        onTap: () => _openStory(index, title, content, key),
        child: Container(
          margin: EdgeInsets.only(bottom: context.responsiveSize(18)),
          padding: EdgeInsets.symmetric(
              horizontal: context.responsiveSize(16),
              vertical: context.responsiveSize(14)),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(context.responsiveSize(20)),
            border: Border.all(
                color: const Color(0xFFFFD36A).withOpacity(0.35), width: 1.2),
          ),
          child: Row(
            children: [
              // Number badge
              Container(
                width: context.responsiveSize(46),
                height: context.responsiveSize(46),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: widget.colors),
                ),
                child: Text(
                  (index + 1).toString().padLeft(2, '0'),
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: context.responsiveFontSize(16)),
                ),
              ),
              SizedBox(width: context.responsiveSize(16)),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: context.responsiveFontSize(16),
                        fontWeight: FontWeight.w600)),
              ),
              if (locked)
                Image.asset('assets/images/lock.png',
                    color: const Color(0xFFFFD36A),
                    height: context.responsiveSize(24),
                    width: context.responsiveSize(24))
              else ...[
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios,
                    size: context.responsiveSize(16), color: Colors.white70),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
