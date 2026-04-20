class Crop {
  final int id;
  final String nameEn;
  final String nameAr;
  final String emoji;
  final double avgYield;
  final int categoryId;

  Crop({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.emoji,
    required this.avgYield,
    required this.categoryId,
  });

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      id: json['id'],
      nameEn: json['name_en'],
      nameAr: json['name_ar'],
      emoji: json['emoji'],
      avgYield: (json['avg_yield_per_donum'] as num).toDouble(),
      categoryId: json['category_id'],
    );
  }

  String getName(String lang) => lang == 'ar' ? nameAr : nameEn;
}
