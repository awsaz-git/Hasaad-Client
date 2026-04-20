class CropCategory {
  final int id;
  final String nameEn;
  final String nameAr;
  final String emoji;

  CropCategory({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.emoji,
  });

  factory CropCategory.fromJson(Map<String, dynamic> json) {
    return CropCategory(
      id: json['id'],
      nameEn: json['name_en'],
      nameAr: json['name_ar'],
      emoji: json['emoji'],
    );
  }

  String getName(String lang) => lang == 'ar' ? nameAr : nameEn;
}
