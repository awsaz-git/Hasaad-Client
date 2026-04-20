class Reminder {
  final String? id;
  final String taskId;
  final DateTime reminderTime;
  final bool isSent;
  final DateTime? createdAt;

  Reminder({
    this.id,
    required this.taskId,
    required this.reminderTime,
    this.isSent = false,
    this.createdAt,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id']?.toString(),
      taskId: json['task_id'],
      reminderTime: DateTime.parse(json['reminder_time']),
      isSent: json['is_sent'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'task_id': taskId,
      'reminder_time': reminderTime.toIso8601String(),
      'is_sent': isSent,
    };
  }
}
