import 'package:flutter/foundation.dart';

// Assuming these models exist in your project.
import '../models/user.dart';
import '../models/task.dart';
import '../models/timesheet.dart';
import '../models/task_creation_data.dart';
import '../models/notification.dart';

// Assuming these services exist and are set up.
import '../services/api_service.dart';
import '../services/storage_service.dart';

class TaskService {
  // Cache keys from the original file
  static const String _tasksKey = 'cached_tasks';
  static const String _timeEntriesKey = 'cached_time_entries';
  static const String _activeTimerKey = 'cached_active_timer';
  static const String _statisticsKey = 'cached_statistics';
  static const String _enhancedStatisticsKey = 'cached_enhanced_statistics';

  // ============== CACHE MANAGEMENT ==============

  static Future<void> _cacheTasks(List<Task> tasks) async {
    try {
      final tasksJson = tasks.map((task) => task.toJson()).toList();
      await StorageService.saveCachedData(_tasksKey, {'tasks': tasksJson});
    } catch (e) {
      debugPrint('Error caching tasks: $e');
    }
  }

  static Future<List<Task>?> _getCachedTasks() async {
    try {
      final cachedData = await StorageService.getCachedData(_tasksKey);
      if (cachedData != null && cachedData['tasks'] != null) {
        final List<dynamic> tasksJson = cachedData['tasks'];
        return tasksJson.map((json) => Task.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error getting cached tasks: $e');
    }
    return null;
  }

  static Future<void> _cacheTimeEntries(List<TimeEntry> entries) async {
    try {
      final entriesJson = entries.map((entry) => entry.toJson()).toList();
      await StorageService.saveCachedData(_timeEntriesKey, {'entries': entriesJson});
    } catch (e) {
      debugPrint('Error caching time entries: $e');
    }
  }

  static Future<List<TimeEntry>?> _getCachedTimeEntries() async {
    try {
      final cachedData = await StorageService.getCachedData(_timeEntriesKey);
      if (cachedData != null && cachedData['entries'] != null) {
        final List<dynamic> entriesJson = cachedData['entries'];
        return entriesJson.map((json) => TimeEntry.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error getting cached time entries: $e');
    }
    return null;
  }

  static Future<void> _cacheActiveTimer(TimeEntry? timer) async {
    try {
      if (timer != null) {
        await StorageService.saveCachedData(_activeTimerKey, timer.toJson());
      } else {
        await StorageService.removeData('cache_$_activeTimerKey');
      }
    } catch (e) {
      debugPrint('Error caching active timer: $e');
    }
  }

  static Future<TimeEntry?> _getCachedActiveTimer() async {
    try {
      final cachedData = await StorageService.getCachedData(_activeTimerKey);
      if (cachedData != null) {
        return TimeEntry.fromJson(cachedData);
      }
    } catch (e) {
      debugPrint('Error getting cached active timer: $e');
    }
    return null;
  }

  // ============== TASK OPERATIONS ==============

  static Future<List<Task>> getTasks({
    String? status,
    String? priority,
    String? category,
    bool? overdue,
    String? search,
    bool useCache = true,
  }) async {
    try {
      final tasks = await ApiService.getTasks(
        status: status,
        priority: priority,
        category: category,
        overdue: overdue,
        search: search,
      );
      await _cacheTasks(tasks);
      return tasks;
    } catch (e) {
      debugPrint('Error getting tasks from API: $e');
      if (useCache) {
        final cachedTasks = await _getCachedTasks();
        if (cachedTasks != null) {
          debugPrint('Using cached tasks');
          return cachedTasks;
        }
      }
      debugPrint('No tasks available (API failed, no cache)');
      return [];
    }
  }

  static Future<Task?> getTask(String taskId) async {
    try {
      return await ApiService.getTask(taskId);
    } catch (e) {
      debugPrint('Error getting task: $e');
      final cachedTasks = await _getCachedTasks();
      if (cachedTasks != null) {
        try {
          return cachedTasks.firstWhere((task) => task.id == taskId);
        } catch (_) {
          debugPrint('Task not found in cache: $taskId');
        }
      }
      return null;
    }
  }

  static Future<Task> createTask(Task task) async {
    try {
      final newTask = await ApiService.createTask(
        title: task.title,
        description: task.description,
        priority: task.priority.toString().split('.').last,
        category: task.category,
        tags: task.tags,
        estimatedHours: task.estimatedHours,
        dueDate: task.dueDate,
      );
      await getTasks(useCache: false); // Refresh cache
      return newTask;
    } catch (e) {
      debugPrint('Error creating task: $e');
      await StorageService.addToSyncQueue({
        'type': 'CREATE_TASK',
        'data': task.toJson(),
      });
      throw Exception('Failed to create task: ${e.toString()}');
    }
  }
  
  // ============== USER & ASSIGNMENT OPERATIONS (NEW) ==============

  /// Get available users for task assignment.
  static Future<List<User>> getAvailableUsers() async {
    try {
      // This call is delegated to ApiService to handle the actual HTTP request.
      return await ApiService.getAvailableUsers();
    } catch (e) {
      debugPrint('Error loading users: ${e.toString()}');
      // No caching strategy defined for users, so we throw.
      // Consider adding caching for offline use if needed.
      throw Exception('Error loading users: ${e.toString()}');
    }
  }

  /// Create task with assignment.
  static Future<void> createTaskWithAssignment(TaskCreationData taskData) async {
    try {
      // Delegated to ApiService
      await ApiService.createTaskWithAssignment(taskData);
      // Refresh the main task list after creation
      await getTasks(useCache: false);
    } catch (e) {
      debugPrint('Error creating task with assignment: $e');
      // Add to sync queue for offline support, similar to the original createTask
      await StorageService.addToSyncQueue({
        'type': 'CREATE_TASK_WITH_ASSIGNMENT',
        'data': taskData.toJson(),
      });
      throw Exception('Error creating task: ${e.toString()}');
    }
  }

  // ============== (CONTINUED) TASK OPERATIONS ==============

  static Future<Task> updateTask(Task task) async {
    try {
      final updatedTask = await ApiService.updateTask(
        task.id,
        title: task.title,
        description: task.description,
        priority: task.priority.toString().split('.').last,
        status: task.status.toString().split('.').last,
        category: task.category,
        tags: task.tags,
        estimatedHours: task.estimatedHours,
        dueDate: task.dueDate,
      );
      await getTasks(useCache: false); // Refresh cache
      return updatedTask;
    } catch (e) {
      debugPrint('Error updating task: $e');
      await StorageService.addToSyncQueue({
        'type': 'UPDATE_TASK',
        'data': task.toJson(),
      });
      throw Exception('Failed to update task: ${e.toString()}');
    }
  }

  static Future<void> deleteTask(String taskId) async {
    try {
      await ApiService.deleteTask(taskId);
      await getTasks(useCache: false); // Refresh cache
    } catch (e) {
      debugPrint('Error deleting task: $e');
      await StorageService.addToSyncQueue({
        'type': 'DELETE_TASK',
        'data': {'taskId': taskId},
      });
      throw Exception('Failed to delete task: ${e.toString()}');
    }
  }

  static Future<Task> toggleTaskStatus(String taskId) async {
    try {
      final updatedTask = await ApiService.toggleTaskStatus(taskId);
      await getTasks(useCache: false); // Refresh cache
      return updatedTask;
    } catch (e) {
      debugPrint('Error toggling task status: $e');
      throw Exception('Failed to update task status: ${e.toString()}');
    }
  }

  static Future<List<Task>> getRecentTasks({int limit = 5}) async {
    try {
      return await ApiService.getRecentTasks(limit: limit);
    } catch (e) {
      debugPrint('Error getting recent tasks: $e');
      final cachedTasks = await _getCachedTasks();
      if (cachedTasks != null) {
        cachedTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return cachedTasks.take(limit).toList();
      }
      return [];
    }
  }

  static Future<List<Task>> getUpcomingTasks({int days = 7}) async {
    try {
      return await ApiService.getUpcomingTasks(days: days);
    } catch (e) {
      debugPrint('Error getting upcoming tasks: $e');
      final cachedTasks = await _getCachedTasks();
      if (cachedTasks != null) {
        final now = DateTime.now();
        final cutoff = now.add(Duration(days: days));
        return cachedTasks.where((task) {
          return task.dueDate != null &&
                 task.status != TaskStatus.completed &&
                 task.dueDate!.isAfter(now) &&
                 task.dueDate!.isBefore(cutoff);
        }).toList();
      }
      return [];
    }
  }

  // ============== TIME TRACKING OPERATIONS ==============

  static Future<List<TimeEntry>> getTimeEntries({
    String? taskId,
    DateTime? startDate,
    DateTime? endDate,
    bool useCache = true,
  }) async {
    try {
      final entries = await ApiService.getTimeEntries(
        taskId: taskId,
        startDate: startDate,
        endDate: endDate,
      );
      await _cacheTimeEntries(entries);
      return entries;
    } catch (e) {
      debugPrint('Error getting time entries from API: $e');
      if (useCache) {
        final cachedEntries = await _getCachedTimeEntries();
        if (cachedEntries != null) {
          var filteredEntries = cachedEntries;
          if (taskId != null) filteredEntries = filteredEntries.where((e) => e.taskId == taskId).toList();
          if (startDate != null) filteredEntries = filteredEntries.where((e) => e.startTime.isAfter(startDate)).toList();
          if (endDate != null) filteredEntries = filteredEntries.where((e) => e.startTime.isBefore(endDate)).toList();
          return filteredEntries;
        }
      }
      return [];
    }
  }

  static Future<TimeEntry?> getActiveTimer() async {
    try {
      final activeTimer = await ApiService.getActiveTimer();
      await _cacheActiveTimer(activeTimer);
      return activeTimer;
    } catch (e) {
      debugPrint('Error getting active timer: $e');
      return await _getCachedActiveTimer();
    }
  }

  static Future<TimeEntry> startTimer(String taskId, String taskTitle, String category) async {
    try {
      final result = await ApiService.startTimer(
        taskId: taskId,
        description: 'Working on $taskTitle',
        category: category,
      );
      final timer = TimeEntry(
        id: result['timeEntry']['id'].toString(),
        taskId: taskId,
        taskTitle: taskTitle,
        startTime: DateTime.parse(result['timeEntry']['start_time']),
        description: result['timeEntry']['description'],
        category: category,
        isRunning: true,
      );
      await _cacheActiveTimer(timer);
      return timer;
    } catch (e) {
      debugPrint('Error starting timer: $e');
      throw Exception('Failed to start timer: ${e.toString()}');
    }
  }

  static Future<TimeEntry?> stopTimer() async {
    try {
      final stoppedEntry = await ApiService.stopTimer();
      await _cacheActiveTimer(null);
      await getTimeEntries(useCache: false);
      return stoppedEntry;
    } catch (e) {
      debugPrint('Error stopping timer: $e');
      throw Exception('Failed to stop timer: ${e.toString()}');
    }
  }

  static Future<TimeEntry?> pauseTimer() async {
    try {
      final pausedEntry = await ApiService.pauseTimer();
      await _cacheActiveTimer(null);
      await getTimeEntries(useCache: false);
      return pausedEntry;
    } catch (e) {
      debugPrint('Error pausing timer: $e');
      throw Exception('Failed to pause timer: ${e.toString()}');
    }
  }

  // ============== STATISTICS AND ANALYTICS ==============

  static Future<Map<String, dynamic>> getTaskStatistics({bool useCache = true}) async {
    try {
      final stats = await ApiService.getTaskStatistics();
      await StorageService.saveCachedData(_statisticsKey, stats);
      return stats;
    } catch (e) {
      debugPrint('Error getting statistics: $e');
      if (useCache) {
        final cachedStats = await StorageService.getCachedData(_statisticsKey);
        if (cachedStats != null) return cachedStats;
      }
      return {
        'general': {'total_tasks': 0, 'completed_tasks': 0, 'in_progress_tasks': 0, 'pending_tasks': 0, 'overdue_tasks': 0, 'completion_rate': 0},
        'timeToday': {'total_minutes': 0, 'session_count': 0},
      };
    }
  }
  
  /// Get enhanced task statistics with assignment info (NEW).
  // static Future<Map<String, dynamic>> getEnhancedTaskStatistics() async {
  //   try {
  //     final stats = await ApiService.getEnhancedTaskStatistics();
  //     // Cache the enhanced statistics
  //     await StorageService.saveCachedData(_enhancedStatisticsKey, stats);
  //     return stats;
  //   } catch (e) {
  //     debugPrint('Error loading enhanced statistics: ${e.toString()}');
  //     // Fall back to cache
  //     final cachedStats = await StorageService.getCachedData(_enhancedStatisticsKey);
  //     if (cachedStats != null) {
  //       debugPrint('Using cached enhanced statistics');
  //       return cachedStats;
  //     }
  //     throw Exception('Error loading statistics: ${e.toString()}');
  //   }
  // }

  static Future<Map<String, dynamic>> getTodayStats() async {
    try {
      return await ApiService.getTodayStats();
    } catch (e) {
      debugPrint('Error getting today stats: $e');
      return {'session_count': 0, 'total_minutes': 0, 'avg_minutes': 0};
    }
  }

  static Future<List<DailyTimesheet>> getWeeklyTimesheet() async {
    // This implementation remains the same.
    try {
      final weeklyStats = await ApiService.getWeeklyStats();
      final List<DailyTimesheet> weeklySheets = [];
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateKey = DateTime(date.year, date.month, date.day);
        final dayStats = weeklyStats.firstWhere(
          (stat) => DateTime.parse(stat['date']).day == date.day,
          orElse: () => {'date': dateKey.toIso8601String(), 'total_minutes': 0, 'session_count': 0},
        );
        final totalMinutes = (dayStats['total_minutes'] as num?)?.toInt() ?? 0;
        weeklySheets.add(DailyTimesheet(date: dateKey, entries: [], totalTime: Duration(minutes: totalMinutes)));
      }
      return weeklySheets;
    } catch (e) {
      debugPrint('Error getting weekly timesheet: $e');
      final List<DailyTimesheet> weeklySheets = [];
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        weeklySheets.add(DailyTimesheet(date: DateTime(date.year, date.month, date.day), entries: [], totalTime: Duration.zero));
      }
      return weeklySheets;
    }
  }

  static Future<List<TimeEntry>> getRecentTimeEntries({int limit = 10}) async {
    try {
      return await ApiService.getRecentTimeEntries(limit: limit);
    } catch (e) {
      debugPrint('Error getting recent time entries: $e');
      final cachedEntries = await _getCachedTimeEntries();
      if (cachedEntries != null) {
        cachedEntries.sort((a, b) => (b.endTime ?? DateTime.now()).compareTo(a.endTime ?? DateTime.now()));
        return cachedEntries.take(limit).toList();
      }
      return [];
    }
  }
  
  // ============== OFFLINE SYNC ==============

  static Future<void> syncOfflineChanges() async {
    try {
      final syncQueue = await StorageService.getSyncQueue();
      for (final operation in syncQueue) {
        try {
          switch (operation['type']) {
            case 'CREATE_TASK':
              await createTask(Task.fromJson(operation['data']));
              break;
            case 'UPDATE_TASK':
              await updateTask(Task.fromJson(operation['data']));
              break;
            case 'DELETE_TASK':
              await deleteTask(operation['data']['taskId']);
              break;
            // Handle new offline operation
            case 'CREATE_TASK_WITH_ASSIGNMENT':
               await createTaskWithAssignment(TaskCreationData.fromJson(operation['data']));
               break;
          }
          await StorageService.removeFromSyncQueue(operation['id']);
        } catch (e) {
          debugPrint('Error syncing operation ${operation['id']}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error syncing offline changes: $e');
    }
  }

  // ============== CACHE CLEANUP ==============

  static Future<void> clearCache() async {
    try {
      await StorageService.removeData('cache_$_tasksKey');
      await StorageService.removeData('cache_$_timeEntriesKey');
      await StorageService.removeData('cache_$_activeTimerKey');
      await StorageService.removeData('cache_$_statisticsKey');
      await StorageService.removeData('cache_$_enhancedStatisticsKey'); // Clear new cache
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  // ============== UTILITY METHODS ==============

  static Future<bool> isOnline() async {
    try {
      return await ApiService.checkConnection();
    } catch (e) {
      return false;
    }
  }

  static Future<void> refreshAllData() async {
    try {
      await Future.wait([
        getTasks(useCache: false),
        getTimeEntries(useCache: false),
        getActiveTimer(),
        getTaskStatistics(),
        // getEnhancedTaskStatistics(), // Refresh new data
      ]);
    } catch (e) {
      debugPrint('Error refreshing all data: $e');
    }
  }

  // Add mock notification methods
  static Future<List<TaskNotification>> getNotifications() async {
    return await ApiService.getNotifications();
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    await ApiService.markNotificationAsRead(notificationId);
  }

  static Future<Duration> getTimeSpentForTask(String taskId) async {
    try {
      final breakdown = await ApiService.getTimeByTask();
      final taskData = breakdown.firstWhere(
        (t) => t['task_id'].toString() == taskId,
        orElse: () => {},
      );
      if (taskData != null && taskData['total_minutes'] != null) {
        final raw = taskData['total_minutes'];
        int minutes;
        if (raw is int) {
          minutes = raw;
        } else if (raw is String) {
          minutes = int.tryParse(raw) ?? 0;
        } else if (raw is num) {
          minutes = raw.toInt();
        } else {
          minutes = 0;
        }
        return Duration(minutes: minutes);
      }
      return Duration.zero;
    } catch (e) {
      debugPrint('Error getting time spent for task: $e');
      return Duration.zero;
    }
  }
}