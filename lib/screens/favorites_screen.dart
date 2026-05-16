import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krishna_stories_app/services/context_extensions.dart';
import '../services/app_text_data.dart';
import '../services/favorite_service.dart';
import '../services/util.dart';
import '../widgets/app_background.dart';
import '../widgets/clear_favorites_dialog.dart';
import 'story_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FavoriteStory> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _favorites = await FavoriteService.getFavorites();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _remove(String key) async {
    await FavoriteService.removeFromFavorites(key);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from favorites'), duration: Duration(seconds: 1)));
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showClearFavoritesDialog(context);
    if (confirm == true) {
      await FavoriteService.clearAllFavorites();
      await _load();
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
      padding: EdgeInsets.all(context.responsiveSize(20)),
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
          SizedBox(width: context.responsiveSize(16)),
          Expanded(
            child: Text(FavoriteStories[selectedLanguage],
                style: TextStyle(
                    color: Colors.white,
                    fontSize: context.responsiveFontSize(24),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
          ),
          if (_favorites.isNotEmpty)
            GestureDetector(
              onTap: _clearAll,
              child: Container(
                padding: EdgeInsets.all(context.responsiveSize(10)),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(context.responsiveSize(14)),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD36A)));
    }
    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border,
                size: context.responsiveSize(80), color: const Color(0xFFFFD36A)),
            const SizedBox(height: 12),
            Text(noFav[selectedLanguage],
                style: TextStyle(
                    fontSize: context.responsiveFontSize(20),
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(noFavDes[selectedLanguage],
                style: TextStyle(
                    fontSize: context.responsiveFontSize(14),
                    color: Colors.white70),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFFFD36A),
      onRefresh: _load,
      child: ListView.builder(
        padding:
            EdgeInsets.symmetric(horizontal: context.responsiveSize(20)),
        itemCount: _favorites.length,
        itemBuilder: (_, i) => _buildCard(_favorites[i], i),
      ),
    );
  }

  Widget _buildCard(FavoriteStory story, int index) {
    return Dismissible(
      key: Key(story.storyKey),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: context.responsiveSize(20)),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(context.responsiveSize(18)),
        ),
        child: Icon(Icons.delete,
            color: Colors.white, size: context.responsiveSize(30)),
      ),
      onDismissed: (_) => _remove(story.storyKey),
      child: Container(
        margin: EdgeInsets.only(bottom: context.responsiveSize(16)),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(context.responsiveSize(20)),
          border: Border.all(
              color: const Color(0xFFFFD36A).withOpacity(0.35), width: 1.2),
        ),
        child: ListTile(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StoryDetailScreen(
                  title: story.title,
                  content: story.content,
                  colors: const [Color(0xFF3A7BD5), Color(0xFF1E3C72)],
                  storyKey: story.storyKey,
                  categoryIndex: story.categoryIndex,
                  storyIndex: story.storyIndex,
                  categoryName: story.categoryName,
                ),
              ),
            );
            await _load();
          },
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFFFD36A),
            child: Text('${index + 1}',
                style: TextStyle(
                    color: const Color(0xFF0B1A3A),
                    fontSize: context.responsiveFontSize(14),
                    fontWeight: FontWeight.bold)),
          ),
          title: Text(story.title,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: context.responsiveFontSize(16))),
          subtitle: Text(story.categoryName,
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: context.responsiveFontSize(14))),
          trailing: Icon(Icons.arrow_forward_ios,
              color: const Color(0xFFFFD36A),
              size: context.responsiveSize(18)),
        ),
      ),
    );
  }
}
