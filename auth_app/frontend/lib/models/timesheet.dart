import 'dart:convert';

class TimeEntry {
  final String id;
  final String taskId;
  final String taskTitle;
  final DateTime startTime;
  final DateTime? endTime;
  final String description;
  final String category;
  final bool isRunning;
  final List<Map<String, String>> intervals;
  final int totalDuration; // in seconds

  TimeEntry({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.startTime,
    this.endTime,
    required this.description,
    required this.category,
    this.isRunning = false,
    this.intervals = const [],
    this.totalDuration = 0,
  });

  factory TimeEntry.fromJson(Map<String, dynamic> json) {
    List<Map<String, String>> intervals = [];
    if (json['intervals'] != null) {
      if (json['intervals'] is String) {
        intervals = List<Map<String, String>>.from(
          (jsonDecode(json['intervals']) as List).map((e) => Map<String, String>.from(e))
        );
      } else if (json['intervals'] is List) {
        intervals = List<Map<String, String>>.from(
          (json['intervals'] as List).map((e) => Map<String, String>.from(e))
        );
      }
    }
    return TimeEntry(
      id: json['id'].toString(),
      taskId: json['task_id'].toString(),
      taskTitle: json['task_title'] ?? '',
      startTime: DateTime.parse(json['start_time']),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      isRunning: json['is_running'] ?? false,
      intervals: intervals,
      totalDuration: json['total_duration'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'description': description,
      'category': category,
      'isRunning': isRunning,
      'intervals': intervals,
      'total_duration': totalDuration,
    };
  }

  TimeEntry copyWith({
    String? id,
    String? taskId,
    String? taskTitle,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
    String? category,
    bool? isRunning,
    List<Map<String, String>>? intervals,
    int? totalDuration,
  }) {
    return TimeEntry(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      description: description ?? this.description,
      category: category ?? this.category,
      isRunning: isRunning ?? this.isRunning,
      intervals: intervals ?? this.intervals,
      totalDuration: totalDuration ?? this.totalDuration,
    );
  }

  Duration get elapsedDuration {
    int seconds = totalDuration;
    if (isRunning && intervals.isNotEmpty && intervals.last['start'] != null && intervals.last['stop'] == null) {
      final start = DateTime.parse(intervals.last['start']!);
      seconds += DateTime.now().difference(start).inSeconds;
    }
    return Duration(seconds: seconds);
  }

  String get durationString {
    final dur = elapsedDuration;
    final hours = dur.inHours;
    final minutes = dur.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  String get formattedDate {
    return '${startTime.day}/${startTime.month}/${startTime.year}';
  }
}

class DailyTimesheet {
  final DateTime date;
  final List<TimeEntry> entries;
  final Duration totalTime;

  DailyTimesheet({
    required this.date,
    required this.entries,
    required this.totalTime,
  });

  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String get totalTimeString {
    final hours = totalTime.inHours;
    final minutes = totalTime.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  Map<String, Duration> get timeByCategory {
    final Map<String, Duration> categoryTime = {};
    for (final entry in entries) {
      categoryTime[entry.category] = 
          (categoryTime[entry.category] ?? Duration.zero) + entry.elapsedDuration;
    }
    return categoryTime;
  }
}