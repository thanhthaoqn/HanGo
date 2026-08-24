class Course {
  static const Set<String> _unavailableUnsplashPhotoIds = {
    'photo-1455390582262-044cdead27d8',
    'photo-1516322893540-334336c253d8',
  };

  final int id;
  final String title;
  final String category;
  final List<String> categories;
  final String creatorName;
  final double stars;
  final String difficulty;
  final String learnerCount;
  final String thumbnailUrl;
  final String status; // 'featured' | 'in_progress' | 'completed'
  final double progressPercentage;
  final double price;
  final String? version;

  const Course({
    required this.id,
    required this.title,
    required this.category,
    this.categories = const [],
    required this.creatorName,
    required this.stars,
    required this.difficulty,
    required this.learnerCount,
    required this.thumbnailUrl,
    required this.status,
    required this.progressPercentage,
    required this.price,
    this.version,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    List<String> parsedCategories = [];
    if (json['categories'] != null && json['categories'] is List) {
      parsedCategories = List<String>.from(
        json['categories'].map((e) => e.toString()),
      );
    } else if (json['categoryNames'] != null && json['categoryNames'] is List) {
      parsedCategories = List<String>.from(
        json['categoryNames'].map((e) => e.toString()),
      );
    } else if (json['categoryName'] != null &&
        json['categoryName'].toString().isNotEmpty) {
      parsedCategories = [json['categoryName'].toString()];
    }

    final catSingle = parsedCategories.isNotEmpty
        ? parsedCategories.first
        : (json['categoryName'] ?? '');

    return Course(
      id: json['id'],
      title: json['title'] ?? '',
      category: catSingle,
      categories: parsedCategories,
      creatorName: json['creatorName'] ?? '',
      stars: (json['rating'] ?? 0.0).toDouble(),
      difficulty: json['difficultyName'] ?? 'Medium',
      learnerCount: '${json['learnersCount'] ?? 0}',
      thumbnailUrl: _sanitizeThumbnailUrl(json['thumbnailUrl']),
      status: 'featured',
      progressPercentage: (json['progressPercentage'] ?? 0.0).toDouble(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      version: json['version'] as String?,
    );
  }

  static String _sanitizeThumbnailUrl(dynamic rawUrl) {
    final url = rawUrl?.toString().trim() ?? '';
    if (_unavailableUnsplashPhotoIds.any(url.contains)) return '';
    return url;
  }
}
