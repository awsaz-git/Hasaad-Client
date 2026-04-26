class CropFinancial {
  final String? id;
  final String farmerId;
  final int cropId;
  final double sellingPricePerTon;
  final double? seedCost;
  final double? fertilizerCost;
  final double? irrigationCost;
  final double? laborCost;
  final double? pesticideCost;
  final double? transportCost;
  final double? otherCost;
  final String? notes;
  final DateTime? createdAt;
  final String? plantingPlanId;

  CropFinancial({
    this.id,
    required this.farmerId,
    required this.cropId,
    required this.sellingPricePerTon,
    this.seedCost,
    this.fertilizerCost,
    this.irrigationCost,
    this.laborCost,
    this.pesticideCost,
    this.transportCost,
    this.otherCost,
    this.notes,
    this.createdAt,
    this.plantingPlanId,
  });

  double get totalExpenses =>
      (seedCost ?? 0) +
      (fertilizerCost ?? 0) +
      (irrigationCost ?? 0) +
      (laborCost ?? 0) +
      (pesticideCost ?? 0) +
      (transportCost ?? 0) +
      (otherCost ?? 0);

  factory CropFinancial.fromJson(Map<String, dynamic> json) {
    return CropFinancial(
      id: json['id']?.toString(),
      farmerId: json['farmer_id'],
      cropId: json['crop_id'],
      sellingPricePerTon: (json['selling_price_per_ton'] as num).toDouble(),
      seedCost: (json['seed_cost'] as num?)?.toDouble(),
      fertilizerCost: (json['fertilizer_cost'] as num?)?.toDouble(),
      irrigationCost: (json['irrigation_cost'] as num?)?.toDouble(),
      laborCost: (json['labor_cost'] as num?)?.toDouble(),
      pesticideCost: (json['pesticide_cost'] as num?)?.toDouble(),
      transportCost: (json['transport_cost'] as num?)?.toDouble(),
      otherCost: (json['other_cost'] as num?)?.toDouble(),
      notes: json['notes'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      plantingPlanId: json['planting_plan_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'farmer_id': farmerId,
      'crop_id': cropId,
      'selling_price_per_ton': sellingPricePerTon,
      if (seedCost != null) 'seed_cost': seedCost,
      if (fertilizerCost != null) 'fertilizer_cost': fertilizerCost,
      if (irrigationCost != null) 'irrigation_cost': irrigationCost,
      if (laborCost != null) 'labor_cost': laborCost,
      if (pesticideCost != null) 'pesticide_cost': pesticideCost,
      if (transportCost != null) 'transport_cost': transportCost,
      if (otherCost != null) 'other_cost': otherCost,
      'notes': notes,
      'planting_plan_id': plantingPlanId,
    };
  }
}
