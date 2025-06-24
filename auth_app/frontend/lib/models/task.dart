import 'package:flutter/material.dart';

// Enums remain the same
enum TaskPriority { low, medium, high, urgent }
enum TaskStatus { pending, inProgress, completed, cancelled }

class Task {
  final String id;
  final String title;
  final String description;
  final TaskPriority priority;
  final TaskStatus status;
  final String category;
  final List<String> tags;

  // Updated fields from the first snippet
  final double estimatedHours;
  final double actualHours;
  final DateTime? startDate;

  // Existing fields
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime? completedAt;

  // Assignment fields
  final String? assignedToId;
  final String? assignedToName;
  final String? createdById;
  final String? createdByName;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    required this.category,
    required this.tags,
    this.estimatedHours = 1.0, // Added with default
    this.actualHours = 0.0,    // Added with default
    this.startDate,            // Added
    this.dueDate,
    required this.createdAt,
    this.completedAt,
    this.assignedToId,
    this.assignedToName,
    this.createdById,
    this.createdByName,
    required this.updatedAt,
  });

  // Merged fromJson factory
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'].toString(),
      title: json['title'] ?? 'Untitled Task',
      description: json['description'] ?? '',
      priority: TaskPriority.values.firstWhere(
        (e) => e.toString().split('.').last == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      status: TaskStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => TaskStatus.pending,
      ),
      category: json['category'] ?? 'General',
      tags: List<String>.from(json['tags'] ?? []),
      estimatedHours: (json['estimated_hours'] as num? ?? 1.0).toDouble(), // Updated
      actualHours: (json['actual_hours'] as num? ?? 0.0).toDouble(),     // Updated
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null, // Updated
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']), // Handles both key styles
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      assignedToId: json['assigned_to']?.toString() ?? json['assigned_to_id']?.toString(),
      assignedToName: json['assigned_to_name'],
      createdById: json['created_by_id']?.toString(),
      createdByName: json['created_by_name'],
      updatedAt: DateTime.parse(json['updated_at'] ?? json['updatedAt'] ?? json['created_at'] ?? json['createdAt']), // Handles both key styles, fallback to createdAt
    );
  }

  // Updated toJson method
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'priority': priority.toString().split('.').last,
      'status': status.toString().split('.').last,
      'category': category,
      'tags': tags,
      'estimated_hours': estimatedHours, // Updated
      'actual_hours': actualHours,       // Updated
      'start_date': startDate?.toIso8601String(), // Updated
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'assigned_to_id': assignedToId,
      'assigned_to_name': assignedToName,
      'created_by_id': createdById,
      'created_by_name': createdByName,
      'updated_at': updatedAt.toIso8601String(), // Added
    };
  }

  // Updated copyWith method
  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskPriority? priority,
    TaskStatus? status,
    String? category,
    List<String>? tags,
    double? estimatedHours,
    double? actualHours,
    DateTime? startDate,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? completedAt,
    String? assignedToId,
    String? assignedToName,
    String? createdById,
    String? createdByName,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      actualHours: actualHours ?? this.actualHours,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      assignedToId: assignedToId ?? this.assignedToId,
      assignedToName: assignedToName ?? this.assignedToName,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // --- GETTERS ---
  // Using the more concise getters from the first snippet

  bool get isOverdue => dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      status != TaskStatus.completed;

  Color get priorityColor {
    switch (priority) {
      case TaskPriority.low: return Colors.green;
      case TaskPriority.medium: return Colors.orange;
      case TaskPriority.high: return Colors.red;
      case TaskPriority.urgent: return Colors.purple;
    }
  }

  String get priorityLabel {
    return priority.toString().split('.').last.toUpperCase();
  }

  Color get statusColor {
    switch (status) {
      case TaskStatus.pending: return Colors.grey;
      case TaskStatus.inProgress: return Colors.blue;
      case TaskStatus.completed: return Colors.green;
      case TaskStatus.cancelled: return Colors.red;
    }
  }

  String get statusLabel {
    // This provides more readable labels than just capitalizing the enum
    switch (status) {
      case TaskStatus.pending: return 'Pending';
      case TaskStatus.inProgress: return 'In Progress';
      case TaskStatus.completed: return 'Completed';
      case TaskStatus.cancelled: return 'Cancelled';
    }
  }
  
  // Kept from the second version
  double get progressPercentage {
    if (status == TaskStatus.completed) return 1.0;
    if (actualHours > 0 && estimatedHours > 0) {
        final progress = actualHours / estimatedHours;
        return progress.clamp(0.0, 1.0); // Ensure progress is between 0 and 1
    }
    if (status == TaskStatus.inProgress) return 0.5; // Default for in-progress tasks without hours
    return 0.0;
  }

  // Compatibility getters for backwards compatibility
  int get estimatedMinutes => (estimatedHours * 60).round();

  // --- OVERRIDES ---
  // Kept from the second version for equality checks and debugging

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Task && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Task(id: $id, title: $title, status: $status, priority: $priority)';
  }
}