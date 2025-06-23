import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../utils/constants.dart';
import '../models/task.dart';
import '../models/timesheet.dart';
import 'storage_service.dart';

class ApiService {
  static final String baseUrl = Constants.baseUrl;
  static const Duration timeout = Duration(seconds: 30);

  // Helper method to get headers with auth token
  static Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await StorageService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Generic API call method with error handling
  static Future<Map<String, dynamic>> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
    Map<String, String>? queryParams,
  }) async {
    try {
      final headers = await _getHeaders(includeAuth: includeAuth);
      final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);

      http.Response response;
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(timeout);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(timeout);
          break;
        case 'PUT':
          response = await http.put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(timeout);
          break;
        case 'PATCH':
          response = await http.patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(timeout);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(timeout);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: responseData['message'] ?? 'Request failed',
          errors: responseData['errors'],
        );
      }
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'No internet connection',
      );
    } on FormatException {
      throw ApiException(
        statusCode: 0,
        message: 'Invalid response format',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  // ============== AUTHENTICATION ENDPOINTS ==============
  
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    return await _makeRequest(
      'POST',
      '/api/auth/register',
      body: {
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
      },
      includeAuth: false,
    );
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    return await _makeRequest(
      'POST',
      '/api/auth/login',
      body: {
        'email': email,
        'password': password,
      },
      includeAuth: false,
    );
  }

  static Future<Map<String, dynamic>> googleSignIn({
    required String idToken,
  }) async {
    return await _makeRequest(
      'POST',
      '/api/auth/google',
      body: {
        'idToken': idToken,
      },
      includeAuth: false,
    );
  }

  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    return await _makeRequest(
      'POST',
      '/api/auth/forgot-password',
      body: {
        'email': email,
      },
      includeAuth: false,
    );
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    return await _makeRequest(
      'POST',
      '/api/auth/reset-password',
      body: {
        'token': token,
        'newPassword': newPassword,
      },
      includeAuth: false,
    );
  }

  static Future<Map<String, dynamic>> verifyEmail({
    required String token,
  }) async {
    return await _makeRequest(
      'POST',
      '/api/auth/verify-email',
      body: {
        'token': token,
      },
      includeAuth: false,
    );
  }

  static Future<Map<String, dynamic>> refreshToken() async {
    return await _makeRequest('POST', '/api/auth/refresh');
  }

  static Future<Map<String, dynamic>> logout() async {
    return await _makeRequest('POST', '/api/auth/logout');
  }

  // ============== TASK ENDPOINTS ==============

  static Future<List<Task>> getTasks({
    String? status,
    String? priority,
    String? category,
    bool? overdue,
    String? search,
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;
    if (priority != null) queryParams['priority'] = priority;
    if (category != null) queryParams['category'] = category;
    if (overdue != null) queryParams['overdue'] = overdue.toString();
    if (search != null) queryParams['search'] = search;
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();

    final response = await _makeRequest(
      'GET',
      '/api/tasks',
      queryParams: queryParams,
    );

    final List<dynamic> tasksJson = response['data'];
    return tasksJson.map((json) => Task.fromJson(json)).toList();
  }

  static Future<Task> getTask(String taskId) async {
    final response = await _makeRequest('GET', '/api/tasks/$taskId');
    return Task.fromJson(response['data']);
  }

  static Future<Task> createTask({
    required String title,
    String? description,
    String? priority,
    String? category,
    List<String>? tags,
    int? estimatedMinutes,
    DateTime? dueDate,
  }) async {
    final response = await _makeRequest(
      'POST',
      '/api/tasks',
      body: {
        'title': title,
        'description': description,
        'priority': priority,
        'category': category,
        'tags': tags,
        'estimatedMinutes': estimatedMinutes,
        'dueDate': dueDate?.toIso8601String(),
      },
    );

    return Task.fromJson(response['data']);
  }

  static Future<Task> updateTask(
    String taskId, {
    String? title,
    String? description,
    String? priority,
    String? status,
    String? category,
    List<String>? tags,
    int? estimatedMinutes,
    DateTime? dueDate,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (priority != null) body['priority'] = priority;
    if (status != null) body['status'] = status;
    if (category != null) body['category'] = category;
    if (tags != null) body['tags'] = tags;
    if (estimatedMinutes != null) body['estimatedMinutes'] = estimatedMinutes;
    if (dueDate != null) body['dueDate'] = dueDate.toIso8601String();

    final response = await _makeRequest(
      'PUT',
      '/api/tasks/$taskId',
      body: body,
    );

    return Task.fromJson(response['data']);
  }

  static Future<Task> toggleTaskStatus(String taskId) async {
    final response = await _makeRequest('PATCH', '/api/tasks/$taskId/toggle-status');
    return Task.fromJson(response['data']);
  }

  static Future<void> deleteTask(String taskId) async {
    await _makeRequest('DELETE', '/api/tasks/$taskId');
  }

  static Future<Map<String, dynamic>> getTaskStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
    if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

    final response = await _makeRequest(
      'GET',
      '/api/tasks/statistics',
      queryParams: queryParams,
    );

    return response['data'];
  }

  static Future<List<Task>> getRecentTasks({int? limit}) async {
    final queryParams = <String, String>{};
    if (limit != null) queryParams['limit'] = limit.toString();

    final response = await _makeRequest(
      'GET',
      '/api/tasks/recent',
      queryParams: queryParams,
    );

    final List<dynamic> tasksJson = response['data'];
    return tasksJson.map((json) => Task.fromJson(json)).toList();
  }

  static Future<List<Task>> getUpcomingTasks({int? days}) async {
    final queryParams = <String, String>{};
    if (days != null) queryParams['days'] = days.toString();

    final response = await _makeRequest(
      'GET',
      '/api/tasks/upcoming',
      queryParams: queryParams,
    );

    final List<dynamic> tasksJson = response['data'];
    return tasksJson.map((json) => Task.fromJson(json)).toList();
  }

  // ============== TIMER ENDPOINTS ==============

  static Future<Map<String, dynamic>> startTaskTimer(
    String taskId, {
    String? description,
  }) async {
    final response = await _makeRequest(
      'POST',
      '/api/tasks/$taskId/start-timer',
      body: {
        'description': description,
      },
    );

    return response['data'];
  }

  static Future<TimeEntry?> stopTaskTimer() async {
    final response = await _makeRequest('POST', '/api/tasks/stop-timer');
    return response['data'] != null ? TimeEntry.fromJson(response['data']) : null;
  }

  static Future<TimeEntry?> getActiveTimer() async {
    final response = await _makeRequest('GET', '/api/tasks/timer/active');
    return response['data'] != null ? TimeEntry.fromJson(response['data']) : null;
  }

  // ============== TIMESHEET ENDPOINTS ==============

  static Future<List<TimeEntry>> getTimeEntries({
    String? taskId,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    bool? isRunning,
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, String>{};
    if (taskId != null) queryParams['taskId'] = taskId;
    if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
    if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();
    if (category != null) queryParams['category'] = category;
    if (isRunning != null) queryParams['isRunning'] = isRunning.toString();
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();

    final response = await _makeRequest(
      'GET',
      '/api/timesheet',
      queryParams: queryParams,
    );

    final List<dynamic> entriesJson = response['data'];
    return entriesJson.map((json) => TimeEntry.fromJson(json)).toList();
  }

  static Future<TimeEntry> createTimeEntry({
    required String taskId,
    required DateTime startTime,
    DateTime? endTime,
    String? description,
    String? category,
  }) async {
    final response = await _makeRequest(
      'POST',
      '/api/timesheet',
      body: {
        'taskId': taskId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'description': description,
        'category': category,
      },
    );

    return TimeEntry.fromJson(response['data']);
  }

  static Future<TimeEntry> updateTimeEntry(
    String entryId, {
    DateTime? endTime,
    String? description,
    bool? isRunning,
  }) async {
    final body = <String, dynamic>{};
    if (endTime != null) body['end_time'] = endTime.toIso8601String();
    if (description != null) body['description'] = description;
    if (isRunning != null) body['is_running'] = isRunning;

    final response = await _makeRequest(
      'PUT',
      '/api/timesheet/$entryId',
      body: body,
    );

    return TimeEntry.fromJson(response['data']);
  }

  static Future<void> deleteTimeEntry(String entryId) async {
    await _makeRequest('DELETE', '/api/timesheet/$entryId');
  }

  static Future<Map<String, dynamic>> startTimer({
    required String taskId,
    String? description,
    String? category,
  }) async {
    final response = await _makeRequest(
      'POST',
      '/api/timesheet/timer/start',
      body: {
        'taskId': taskId,
        'description': description,
        'category': category,
      },
    );

    return response['data'];
  }

  static Future<TimeEntry?> stopTimer() async {
    final response = await _makeRequest('POST', '/api/timesheet/timer/stop');
    return response['data'] != null ? TimeEntry.fromJson(response['data']) : null;
  }

  // ============== TIMESHEET STATISTICS ==============

  static Future<Map<String, dynamic>> getTodayStats() async {
    final response = await _makeRequest('GET', '/api/timesheet/stats/today');
    return response['data'];
  }

  static Future<List<Map<String, dynamic>>> getWeeklyStats() async {
    final response = await _makeRequest('GET', '/api/timesheet/stats/weekly');
    return List<Map<String, dynamic>>.from(response['data']);
  }

  static Future<List<Map<String, dynamic>>> getMonthlyStats({
    int? month,
    int? year,
  }) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    final response = await _makeRequest(
      'GET',
      '/api/timesheet/stats/monthly',
      queryParams: queryParams,
    );

    return List<Map<String, dynamic>>.from(response['data']);
  }

  static Future<List<Map<String, dynamic>>> getTimeByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
    if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

    final response = await _makeRequest(
      'GET',
      '/api/timesheet/breakdown/category',
      queryParams: queryParams,
    );

    return List<Map<String, dynamic>>.from(response['data']);
  }

  static Future<List<Map<String, dynamic>>> getTimeByTask({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
    if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

    final response = await _makeRequest(
      'GET',
      '/api/timesheet/breakdown/task',
      queryParams: queryParams,
    );

    return List<Map<String, dynamic>>.from(response['data']);
  }

  static Future<Map<String, dynamic>> getDailyTimesheet(DateTime date) async {
    final dateString = date.toIso8601String().split('T')[0];
    final response = await _makeRequest('GET', '/api/timesheet/daily/$dateString');
    return response['data'];
  }

  static Future<List<TimeEntry>> getRecentTimeEntries({int? limit}) async {
    final queryParams = <String, String>{};
    if (limit != null) queryParams['limit'] = limit.toString();

    final response = await _makeRequest(
      'GET',
      '/api/timesheet/recent',
      queryParams: queryParams,
    );

    final List<dynamic> entriesJson = response['data'];
    return entriesJson.map((json) => TimeEntry.fromJson(json)).toList();
  }

  static Future<Map<String, dynamic>> getTimesheetReport({
    required DateTime startDate,
    required DateTime endDate,
    String format = 'json',
  }) async {
    final queryParams = {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'format': format,
    };

    final response = await _makeRequest(
      'GET',
      '/api/timesheet/reports/timesheet',
      queryParams: queryParams,
    );

    return response['data'];
  }

  // ============== UTILITY METHODS ==============

  static Future<bool> checkConnection() async {
    try {
      final response = await _makeRequest('GET', '/health', includeAuth: false);
      return response['status'] == 'OK';
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getApiStatus() async {
    return await _makeRequest('GET', '/api/status', includeAuth: false);
  }
}

// Custom exception class for API errors
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final List<String>? errors;

  ApiException({
    required this.statusCode,
    required this.message,
    this.errors,
  });

  @override
  String toString() {
    if (errors != null && errors!.isNotEmpty) {
      return 'ApiException ($statusCode): $message\nErrors: ${errors!.join(', ')}';
    }
    return 'ApiException ($statusCode): $message';
  }

  bool get isNetworkError => statusCode == 0;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidationError => statusCode == 400;
  bool get isServerError => statusCode >= 500;
}