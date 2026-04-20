class PlantingPlan {
  final String? id;
  final String farmerId;
  final int cropId;
  final int governorateId;
  final double areaDonums;
  final double? estimatedYieldTons;
  final bool aiYieldPredicted;
  final String status;
  final DateTime plantingDate;
  final DateTime harvestDate;

  PlantingPlan({
    this.id,
    required this.farmerId,
    required this.cropId,
    required this.governorateId,
    required this.areaDonums,
    this.estimatedYieldTons,
    this.aiYieldPredicted = false,
    required this.status,
    required this.plantingDate,
    required this.harvestDate,
  });

  factory PlantingPlan.fromJson(Map<String, dynamic> json) {
    return PlantingPlan(
      id: json['id']?.toString(),
      farmerId: json['farmer_id'],
      cropId: json['crop_id'],
      governorateId: json['governorate_id'],
      areaDonums: (json['area_donums'] as num).toDouble(),
      estimatedYieldTons: json['estimated_yield_tons'] != null ? (json['estimated_yield_tons'] as num).toDouble() : null,
      aiYieldPredicted: json['ai_yield_predicted'] ?? false,
      status: json['status'],
      plantingDate: DateTime.parse(json['planting_date']),
      harvestDate: DateTime.parse(json['expected_harvest_date']), // Fixed column name
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'farmer_id': farmerId,
      'crop_id': cropId,
      'governorate_id': governorateId,
      'area_donums': areaDonums,
      'estimated_yield_tons': estimatedYieldTons,
      'ai_yield_predicted': aiYieldPredicted,
      'status': status,
      'planting_date': plantingDate.toIso8601String().split('T')[0],
      'expected_harvest_date': harvestDate.toIso8601String().split('T')[0], // Fixed column name
    };
  }
}
