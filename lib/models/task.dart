class Task {
  final String? id;
  final String farmerId;
  final String title;
  final String? description;
  final DateTime taskDate;
  final bool isCompleted;
  final String? plantingPlanId;
  final DateTime? createdAt;

  Task({
    this.id,
    required this.farmerId,
    required this.title,
    this.description,
    required this.taskDate,
    this.isCompleted = false,
    this.plantingPlanId,
    this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id']?.toString(),
      farmerId: json['farmer_id'],
      title: json['title'],
      description: json['description'],
      taskDate: DateTime.parse(json['task_date']),
      isCompleted: json['is_completed'] ?? false,
      plantingPlanId: json['planting_plan_id']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'farmer_id': farmerId,
      'title': title,
      'description': description,
      'task_date': taskDate.toIso8601String().split('T')[0],
      'is_completed': isCompleted,
      if (plantingPlanId != null) 'planting_plan_id': plantingPlanId,
    };
  }
}
