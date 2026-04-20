class AppNotification {
  final String? id;
  final String farmerId;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification({
    this.id,
    required this.farmerId,
    required this.title,
    required this.message,
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString(),
      farmerId: json['farmer_id'],
      title: json['title'],
      message: json['message'],
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'farmer_id': farmerId,
      'title': title,
      'message': message,
      'is_read': isRead,
    };
  }
}
