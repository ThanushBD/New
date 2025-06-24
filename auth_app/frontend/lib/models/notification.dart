/// Model for task notifications
class TaskNotification {
  final String id;
  final String taskId;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  TaskNotification({
    required this.id,
    required this.taskId,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory TaskNotification.fromJson(Map<String, dynamic> json) {
    return TaskNotification(
      id: json['id'].toString(),
      taskId: json['task_id'].toString(),
      type: json['type'],
      title: json['title'],
      message: json['message'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'type': type,
      'title': title,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}