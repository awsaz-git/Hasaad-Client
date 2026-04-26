class CropFinancial {
  final String? id;
  final String farmerId;
  final int cropId;
  final double sellingPricePerTon;
  final double totalExpenses;
  final String? notes;
  final DateTime? createdAt;

  CropFinancial({
    this.id,
    required this.farmerId,
    required this.cropId,
    required this.sellingPricePerTon,
    required this.totalExpenses,
    this.notes,
    this.createdAt,
  });

  factory CropFinancial.fromJson(Map<String, dynamic> json) {
    return CropFinancial(
      id: json['id'].toString(),
      farmerId: json['farmer_id'],
      cropId: json['crop_id'],
      sellingPricePerTon: (json['selling_price_per_ton'] as num).toDouble(),
      totalExpenses: (json['total_expenses'] as num).toDouble(),
      notes: json['notes'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'farmer_id': farmerId,
      'crop_id': cropId,
      'selling_price_per_ton': sellingPricePerTon,
      'total_expenses': totalExpenses,
      'notes': notes,
    };
  }
}
