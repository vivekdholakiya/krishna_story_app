import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:krishna_stories_app/services/context_extensions.dart';
import '../model/caregory_model.dart';
import '../services/analytics_service.dart';
import '../services/app_text_data.dart';
import '../services/util.dart';
import '../widgets/app_background.dart';
import '../widgets/app_header.dart';
import 'story_list_screen.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen>
    with SingleTickerProviderStateMixin {
  List<StoryCategory> _categories = [];
  late AnimationController _fadeController;
  String _searchQuery = '';
  bool _isLoading = true;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    setState(() => _searchQuery = v);
    _searchDebounce?.cancel();
    if (v.trim().isEmpty) return;
    _searchDebounce = Timer(const Duration(milliseconds: 700), () {
      AnalyticsService.instance.logSearch(
        query: v,
        resultCount: _filtered.length,
        lang: selectedLanguage,
      );
    });
  }

  Future<void> _loadData() async {
    // Use cache if available — avoids re-parsing JSON on every visit
    if (cachedCategories != null && cachedStoryDetails != null) {
      setState(() {
        _categories = cachedCategories!;
        _isLoading = false;
      });
      _fadeController.forward();
      return;
    }

    try {
      final catJson = await rootBundle.loadString('assets/$selectedJsonFile');
      final detailJson =
          await rootBundle.loadString('assets/krishna_story_detail.json');

      final catData = json.decode(catJson) as Map<String, dynamic>;
      final detailData = json.decode(detailJson) as Map<String, dynamic>;

      final cats = (catData['krishna_story_categories'] as List)
          .map((e) => StoryCategory.fromJson(e as Map<String, dynamic>))
          .toList();

      // Merge data1, data2... into a single flat map
      final merged = <String, dynamic>{};
      detailData.forEach((_, v) {
        if (v is Map) merged.addAll(v.cast<String, dynamic>());
      });

      // Store in cache
      cachedCategories = cats;
      cachedStoryDetails = merged;

      setState(() {
        _categories = cats;
        _isLoading = false;
      });
      _fadeController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<StoryCategory> get _filtered {
    if (_searchQuery.isEmpty) return _categories;
    final q = _searchQuery.toLowerCase();
    return _categories.where((c) => c.category.toLowerCase().contains(q)).toList();
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
                  child: AppHeader(title: KrishnaLeelas[selectedLanguage]),
                ),
                _buildSearchBar(),
                SizedBox(height: context.responsiveSize(16)),
                Expanded(child: _buildGrid()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: context.responsiveSize(20),
          vertical: context.responsiveSize(8)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(context.responsiveSize(18)),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: TextField(
          style: const TextStyle(color: Colors.white),
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: searchHint[selectedLanguage],
            hintStyle: TextStyle(
                color: Colors.white70,
                fontSize: context.responsiveFontSize(14)),
            prefixIcon:
                const Icon(Icons.search, color: Color(0xFFFFD36A)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
                horizontal: context.responsiveSize(20),
                vertical: context.responsiveSize(14)),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD36A)));
    }
    final filtered = _filtered;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.responsiveSize(16)),
      child: MasonryGridView.count(
        key: ValueKey(_searchQuery),
        crossAxisCount: 2,
        mainAxisSpacing: context.responsiveSize(16),
        crossAxisSpacing: context.responsiveSize(16),
        itemCount: filtered.length,
        itemBuilder: (_, i) => _buildCard(filtered[i], i),
      ),
    );
  }

  Widget _buildCard(StoryCategory category, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) =>
          Transform.scale(scale: v, child: Opacity(opacity: v, child: child)),
      child: GestureDetector(
        onTap: () {
          AnalyticsService.instance.logCategoryTap(
            categoryIndex: index,
            categoryName: category.category,
            lang: selectedLanguage,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoriesListScreen(
                category: category,
                colors: const [Color(0xFF3A7BD5), Color(0xFF1E3C72)],
                categoryIndex: index,
                storyDetails: cachedStoryDetails ?? {},
              ),
            ),
          );
        },
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(context.responsiveSize(18)),
                border: Border.all(color: const Color(0xFFFFD36A).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/caregory_img/${category.id}.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: context.responsiveSize(8)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.responsiveSize(4)),
              child: Text(
                category.category,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: context.responsiveFontSize(18),
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
