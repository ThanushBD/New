import 'user.dart';
import 'task.dart';

/// Data class for task creation with assignment information
class TaskCreationData {
  final String title;
  final String description;
  final String category;
  final TaskPriority priority;
  final DateTime? dueDate;
  final int estimatedHours;
  final List<String> tags;
  final User assignedTo;
  final User createdBy;

  TaskCreationData({
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    this.dueDate,
    required this.estimatedHours,
    required this.tags,
    required this.assignedTo,
    required this.createdBy,
  });

  /// Convert to Task object
  Task toTask() {
    return Task(
      id: '', // Will be set by the backend
      title: title,
      description: description,
      category: category,
      priority: priority,
      status: TaskStatus.pending,
      dueDate: dueDate,
      estimatedHours: estimatedHours.toDouble(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tags: tags,
      assignedToId: assignedTo.id,
      assignedToName: assignedTo.fullName,
      createdById: createdBy.id,
      createdByName: createdBy.fullName,
    );
  }

  /// Convert to JSON for API calls
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'priority': priority.toString().split('.').last,
      'due_date': dueDate?.toIso8601String(),
      'estimated_hours': estimatedHours,
      'tags': tags,
      'assigned_to_id': assignedTo.id,
      'created_by_id': createdBy.id,
    };
  }

  factory TaskCreationData.fromJson(Map<String, dynamic> json) {
    return TaskCreationData(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      priority: TaskPriority.values.firstWhere(
        (e) => e.toString().split('.').last == (json['priority'] ?? 'medium'),
        orElse: () => TaskPriority.medium,
      ),
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null,
      estimatedHours: json['estimated_hours'] is int
        ? json['estimated_hours']
        : int.tryParse(json['estimated_hours']?.toString() ?? '1') ?? 1,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      assignedTo: User(
        id: json['assigned_to_id'] ?? '',
        email: json['assigned_to_email'] ?? '',
        firstName: json['assigned_to_first_name'] ?? '',
        lastName: json['assigned_to_last_name'] ?? '',
      ),
      createdBy: User(
        id: json['created_by_id'] ?? '',
        email: json['created_by_email'] ?? '',
        firstName: json['created_by_first_name'] ?? '',
        lastName: json['created_by_last_name'] ?? '',
      ),
    );
  }
}