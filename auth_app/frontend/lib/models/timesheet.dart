class TimeEntry {
  final String id;
  final String taskId;
  final String taskTitle;
  final DateTime startTime;
  final DateTime? endTime;
  final String description;
  final String category;
  final bool isRunning;

  TimeEntry({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.startTime,
    this.endTime,
    required this.description,
    required this.category,
    this.isRunning = false,
  });

  factory TimeEntry.fromJson(Map<String, dynamic> json) {
    return TimeEntry(
      id: json['id'],
      taskId: json['taskId'],
      taskTitle: json['taskTitle'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      description: json['description'],
      category: json['category'],
      isRunning: json['isRunning'] ?? false,
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
    );
  }

  Duration get duration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    } else if (isRunning) {
      return DateTime.now().difference(startTime);
    }
    return Duration.zero;
  }

  String get durationString {
    final dur = duration;
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
          (categoryTime[entry.category] ?? Duration.zero) + entry.duration;
    }
    return categoryTime;
  }
}