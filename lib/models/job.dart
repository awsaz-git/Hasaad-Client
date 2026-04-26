import 'package:intl/intl.dart';

class Job {
  final String? id;
  final String farmerId;
  final String title;
  final String description;
  final int governorateId;
  final String locationText;
  final DateTime startDate;
  final DateTime endDate;
  final String startTime;
  final String endTime;
  final String workHours;
  final int workersNeeded;
  final bool providesTransportation;
  final bool providesFood;
  final bool providesAccommodation;
  final bool isVolunteering;
  final double? paymentAmount;
  final String? paymentType; // daily, hourly, total
  final bool isActive;
  final DateTime? createdAt;
  final int applicantCount;

  Job({
    this.id,
    required this.farmerId,
    required this.title,
    required this.description,
    required this.governorateId,
    required this.locationText,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.workHours,
    required this.workersNeeded,
    this.providesTransportation = false,
    this.providesFood = false,
    this.providesAccommodation = false,
    this.isVolunteering = false,
    this.paymentAmount,
    this.paymentType,
    this.isActive = true,
    this.createdAt,
    this.applicantCount = 0,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'],
      farmerId: json['farmer_id'],
      title: json['title'],
      description: json['description'],
      governorateId: json['governorate_id'],
      locationText: json['location_text'] ?? '',
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      workHours: json['work_hours'] ?? '',
      workersNeeded: json['workers_needed'] ?? 1,
      providesTransportation: json['provides_transportation'] ?? false,
      providesFood: json['provides_food'] ?? false,
      providesAccommodation: json['provides_accommodation'] ?? false,
      isVolunteering: json['is_volunteering'] ?? false,
      paymentAmount: (json['payment_amount'] as num?)?.toDouble(),
      paymentType: json['payment_type'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      applicantCount: json['applicant_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'farmer_id': farmerId,
      'title': title,
      'description': description,
      'governorate_id': governorateId,
      'location_text': locationText,
      'start_date': DateFormat('yyyy-MM-dd').format(startDate),
      'end_date': DateFormat('yyyy-MM-dd').format(endDate),
      'start_time': startTime,
      'end_time': endTime,
      'work_hours': workHours,
      'workers_needed': workersNeeded,
      'provides_transportation': providesTransportation,
      'provides_food': providesFood,
      'provides_accommodation': providesAccommodation,
      'is_volunteering': isVolunteering,
      'payment_amount': paymentAmount,
      'payment_type': paymentType,
      'is_active': isActive,
    };
  }
}

class JobApplicant {
  final String id;
  final String jobId;
  final String fullName;
  final String phone;
  final String? email;
  final String? notes;
  final DateTime createdAt;

  JobApplicant({
    required this.id,
    required this.jobId,
    required this.fullName,
    required this.phone,
    this.email,
    this.notes,
    required this.createdAt,
  });

  factory JobApplicant.fromJson(Map<String, dynamic> json) {
    return JobApplicant(
      id: json['id'],
      jobId: json['job_id'],
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
