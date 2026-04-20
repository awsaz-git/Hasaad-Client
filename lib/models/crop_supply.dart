class CropSupply {
  final int id;
  final int cropId;
  final int governorateId;
  final double totalAreaDonums;
  final double totalEstimatedTons;
  final int activePlansCount;
  final DateTime supplyDate;

  CropSupply({
    required this.id,
    required this.cropId,
    required this.governorateId,
    required this.totalAreaDonums,
    required this.totalEstimatedTons,
    required this.activePlansCount,
    required this.supplyDate,
  });

  factory CropSupply.fromJson(Map<String, dynamic> json) {
    return CropSupply(
      id: json['id'],
      cropId: json['crop_id'],
      governorateId: json['governorate_id'],
      totalAreaDonums: (json['total_area_donums'] as num).toDouble(),
      totalEstimatedTons: (json['total_estimated_tons'] as num).toDouble(),
      activePlansCount: json['active_plans_count'],
      supplyDate: DateTime.parse(json['supply_date']),
    );
  }
}
