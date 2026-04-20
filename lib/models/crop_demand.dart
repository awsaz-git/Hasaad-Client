class CropDemand {
  final int id;
  final int cropId;
  final double demandTons;
  final DateTime demandDate;
  final String? notesEn;
  final String? notesAr;

  CropDemand({
    required this.id,
    required this.cropId,
    required this.demandTons,
    required this.demandDate,
    this.notesEn,
    this.notesAr,
  });

  factory CropDemand.fromJson(Map<String, dynamic> json) {
    return CropDemand(
      id: json['id'],
      cropId: json['crop_id'],
      demandTons: (json['demand_tons'] as num).toDouble(),
      demandDate: DateTime.parse(json['demand_date']),
      notesEn: json['notes_en'],
      notesAr: json['notes_ar'],
    );
  }

  String? getNotes(String lang) => lang == 'ar' ? notesAr : notesEn;
}
