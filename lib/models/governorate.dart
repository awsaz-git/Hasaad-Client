class Governorate {
  final int id;
  final String nameEn;
  final String nameAr;

  Governorate({
    required this.id,
    required this.nameEn,
    required this.nameAr,
  });

  factory Governorate.fromJson(Map<String, dynamic> json) {
    return Governorate(
      id: json['id'],
      nameEn: json['name_en'],
      nameAr: json['name_ar'],
    );
  }

  String getName(String languageCode) {
    return languageCode == 'ar' ? nameAr : nameEn;
  }
}
