class StoryCategory {
  final String category;
  final String id;
  final List<String> stories;

  const StoryCategory({
    required this.category,
    required this.id,
    required this.stories,
  });

  factory StoryCategory.fromJson(Map<String, dynamic> json) {
    return StoryCategory(
      category: json['category'] as String,
      id: json['id'] as String,
      stories: List<String>.from(json['stories'] as List),
    );
  }
}
