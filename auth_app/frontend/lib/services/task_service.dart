import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/timesheet.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class TaskService {
  static const String _tasksKey = 'cached_tasks';
  static const String _timeEntriesKey = 'cached_time_entries';
  static const String _activeTimerKey = 'cached_active_timer';
  static const String _statisticsKey = 'cached_statistics';

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
      // Try to get from API first
      final tasks = await ApiService.getTasks(
        status: status,
        priority: priority,
        category: category,
        overdue: overdue,
        search: search,
      );
      
      // Cache the results
      await _cacheTasks(tasks);
      return tasks;
    } catch (e) {
      debugPrint('Error getting tasks from API: $e');
      
      // Fall back to cache if API fails and cache is allowed
      if (useCache) {
        final cachedTasks = await _getCachedTasks();
        if (cachedTasks != null) {
          debugPrint('Using cached tasks');
          return cachedTasks;
        }
      }
      
      // If both API and cache fail, return empty list
      debugPrint('No tasks available (API failed, no cache)');
      return [];
    }
  }

  static Future<Task?> getTask(String taskId) async {
    try {
      return await ApiService.getTask(taskId);
    } catch (e) {
      debugPrint('Error getting task: $e');
      
      // Try to find in cached tasks
      final cachedTasks = await _getCachedTasks();
      if (cachedTasks != null) {
        try {
          return cachedTasks.firstWhere((task) => task.id == taskId);
        } catch (e) {
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
        estimatedMinutes: task.estimatedMinutes,
        dueDate: task.dueDate,
      );

      // Refresh cached tasks
      await getTasks(useCache: false);
      
      return newTask;
    } catch (e) {
      debugPrint('Error creating task: $e');
      
      // Add to sync queue for offline support
      await StorageService.addToSyncQueue({
        'type': 'CREATE_TASK',
        'data': task.toJson(),
      });
      
      throw Exception('Failed to create task: ${e.toString()}');
    }
  }

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
        estimatedMinutes: task.estimatedMinutes,
        dueDate: task.dueDate,
      );

      // Refresh cached tasks
      await getTasks(useCache: false);
      
      return updatedTask;
    } catch (e) {
      debugPrint('Error updating task: $e');
      
      // Add to sync queue for offline support
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
      
      // Refresh cached tasks
      await getTasks(useCache: false);
    } catch (e) {
      debugPrint('Error deleting task: $e');
      
      // Add to sync queue for offline support
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
      
      // Refresh cached tasks
      await getTasks(useCache: false);
      
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
      
      // Fall back to cached tasks and return recent ones
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
      
      // Fall back to cached tasks and filter upcoming ones
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
      
      // Cache the results
      await _cacheTimeEntries(entries);
      return entries;
    } catch (e) {
      debugPrint('Error getting time entries from API: $e');
      
      // Fall back to cache if API fails
      if (useCache) {
        final cachedEntries = await _getCachedTimeEntries();
        if (cachedEntries != null) {
          // Apply filters to cached data
          var filteredEntries = cachedEntries;
          
          if (taskId != null) {
            filteredEntries = filteredEntries.where((e) => e.taskId == taskId).toList();
          }
          
          if (startDate != null) {
            filteredEntries = filteredEntries.where((e) => e.startTime.isAfter(startDate)).toList();
          }
          
          if (endDate != null) {
            filteredEntries = filteredEntries.where((e) => e.startTime.isBefore(endDate)).toList();
          }
          
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
      
      // Fall back to cached active timer
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
      
      // Create TimeEntry from result
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
      await _cacheActiveTimer(null); // Clear cached active timer
      
      // Refresh time entries cache
      await getTimeEntries(useCache: false);
      
      return stoppedEntry;
    } catch (e) {
      debugPrint('Error stopping timer: $e');
      throw Exception('Failed to stop timer: ${e.toString()}');
    }
  }

  // ============== STATISTICS AND ANALYTICS ==============

  static Future<Map<String, dynamic>> getTaskStatistics() async {
    try {
      final stats = await ApiService.getTaskStatistics();
      
      // Cache statistics
      await StorageService.saveCachedData(_statisticsKey, stats);
      
      return stats;
    } catch (e) {
      debugPrint('Error getting statistics: $e');
      
      // Fall back to cached statistics
      final cachedStats = await StorageService.getCachedData(_statisticsKey);
      if (cachedStats != null) {
        return cachedStats;
      }
      
      // Return default stats if everything fails
      return {
        'general': {
          'total_tasks': 0,
          'completed_tasks': 0,
          'in_progress_tasks': 0,
          'pending_tasks': 0,
          'overdue_tasks': 0,
          'completion_rate': 0,
        },
        'timeToday': {
          'total_minutes': 0,
          'session_count': 0,
        },
      };
    }
  }

  static Future<Map<String, dynamic>> getTodayStats() async {
    try {
      return await ApiService.getTodayStats();
    } catch (e) {
      debugPrint('Error getting today stats: $e');
      return {
        'session_count': 0,
        'total_minutes': 0,
        'avg_minutes': 0,
      };
    }
  }

  static Future<List<DailyTimesheet>> getWeeklyTimesheet() async {
    try {
      final weeklyStats = await ApiService.getWeeklyStats();
      
      // Convert to DailyTimesheet objects
      final List<DailyTimesheet> weeklySheets = [];
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateKey = DateTime(date.year, date.month, date.day);
        
        // Find stats for this date
        final dayStats = weeklyStats.firstWhere(
          (stat) => DateTime.parse(stat['date']).day == date.day,
          orElse: () => {
            'date': dateKey.toIso8601String(),
            'total_minutes': 0,
            'session_count': 0,
          },
        );
        
        final totalMinutes = (dayStats['total_minutes'] as num?)?.toInt() ?? 0;
        final totalTime = Duration(minutes: totalMinutes);
        
        weeklySheets.add(DailyTimesheet(
          date: dateKey,
          entries: [], // We don't need individual entries for the summary
          totalTime: totalTime,
        ));
      }
      
      return weeklySheets;
    } catch (e) {
      debugPrint('Error getting weekly timesheet: $e');
      
      // Return empty weekly timesheet
      final List<DailyTimesheet> weeklySheets = [];
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateKey = DateTime(date.year, date.month, date.day);
        
        weeklySheets.add(DailyTimesheet(
          date: dateKey,
          entries: [],
          totalTime: Duration.zero,
        ));
      }
      
      return weeklySheets;
    }
  }

  static Future<List<TimeEntry>> getRecentTimeEntries({int limit = 10}) async {
    try {
      return await ApiService.getRecentTimeEntries(limit: limit);
    } catch (e) {
      debugPrint('Error getting recent time entries: $e');
      
      // Fall back to cached entries
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
              final taskData = operation['data'];
              final task = Task.fromJson(taskData);
              await createTask(task);
              break;
              
            case 'UPDATE_TASK':
              final taskData = operation['data'];
              final task = Task.fromJson(taskData);
              await updateTask(task);
              break;
              
            case 'DELETE_TASK':
              final taskId = operation['data']['taskId'];
              await deleteTask(taskId);
              break;
          }
          
          // Remove successful operation from queue
          await StorageService.removeFromSyncQueue(operation['id']);
        } catch (e) {
          debugPrint('Error syncing operation ${operation['id']}: $e');
          // Keep operation in queue for later retry
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
      // Refresh all cached data
      await Future.wait([
        getTasks(useCache: false),
        getTimeEntries(useCache: false),
        getActiveTimer(),
        getTaskStatistics(),
      ]);
    } catch (e) {
      debugPrint('Error refreshing all data: $e');
    }
  }
}