class Profile {
  final String id;
  final String nationalId;
  final String fullName;
  final String governorate;
  final int governorateId;
  final double landSize;

  Profile({
    required this.id,
    required this.nationalId,
    required this.fullName,
    required this.governorate,
    required this.governorateId,
    required this.landSize,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      nationalId: json['national_id'],
      fullName: json['full_name'],
      governorate: json['governorate'],
      governorateId: json['governorate_id'],
      landSize: (json['land_size'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'national_id': nationalId,
      'full_name': fullName,
      'governorate': governorate,
      'governorate_id': governorateId,
      'land_size': landSize,
    };
  }
}
