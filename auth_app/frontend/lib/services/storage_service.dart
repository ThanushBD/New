import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import '../utils/constants.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();
  
  // Secure storage for sensitive data
  static Future<void> saveToken(String token) async {
    await _storage.write(key: Constants.tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: Constants.tokenKey);
  }

  static Future<void> saveUser(User user) async {
    await _storage.write(key: Constants.userKey, value: jsonEncode(user.toJson()));
  }

  static Future<User?> getUser() async {
    final userJson = await _storage.read(key: Constants.userKey);
    if (userJson != null) {
      return User.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // Non-secure storage for app data
  static Future<void> saveData(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> getData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> removeData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  // App settings
  static Future<void> saveAppSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_settings', jsonEncode(settings));
  }

  static Future<Map<String, dynamic>> getAppSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('app_settings');
    if (settingsJson != null) {
      return jsonDecode(settingsJson);
    }
    return {
      'theme': 'system',
      'notifications': true,
      'autoStartTimer': false,
      'dailyGoalMinutes': 480, // 8 hours
    };
  }

  // Cache management
  static Future<void> saveCachedData(String key, Map<String, dynamic> data, {Duration? expiry}) async {
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': expiry?.inMilliseconds,
    };
    await saveData('cache_$key', jsonEncode(cacheData));
  }

  static Future<Map<String, dynamic>?> getCachedData(String key) async {
    final cachedJson = await getData('cache_$key');
    if (cachedJson != null) {
      final cache = jsonDecode(cachedJson);
      final timestamp = cache['timestamp'] as int;
      final expiry = cache['expiry'] as int?;
      
      if (expiry != null) {
        final expiryTime = DateTime.fromMillisecondsSinceEpoch(timestamp).add(Duration(milliseconds: expiry));
        if (DateTime.now().isAfter(expiryTime)) {
          await removeData('cache_$key');
          return null;
        }
      }
      
      return Map<String, dynamic>.from(cache['data']);
    }
    return null;
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('cache_')).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // Offline data storage
  static Future<void> saveOfflineData(String endpoint, Map<String, dynamic> data) async {
    final offlineData = await getOfflineData();
    offlineData[endpoint] = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await saveData('offline_data', jsonEncode(offlineData));
  }

  static Future<Map<String, dynamic>> getOfflineData() async {
    final offlineJson = await getData('offline_data');
    if (offlineJson != null) {
      return Map<String, dynamic>.from(jsonDecode(offlineJson));
    }
    return {};
  }

  static Future<void> clearOfflineData() async {
    await removeData('offline_data');
  }

  // Sync queue for offline operations
  static Future<void> addToSyncQueue(Map<String, dynamic> operation) async {
    final queue = await getSyncQueue();
    queue.add({
      ...operation,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await saveData('sync_queue', jsonEncode(queue));
  }

  static Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final queueJson = await getData('sync_queue');
    if (queueJson != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(queueJson));
    }
    return [];
  }

  static Future<void> removeFromSyncQueue(String operationId) async {
    final queue = await getSyncQueue();
    queue.removeWhere((op) => op['id'] == operationId);
    await saveData('sync_queue', jsonEncode(queue));
  }

  static Future<void> clearSyncQueue() async {
    await removeData('sync_queue');
  }

  // Recent searches
  static Future<void> saveRecentSearch(String query) async {
    final searches = await getRecentSearches();
    searches.removeWhere((search) => search == query);
    searches.insert(0, query);
    
    // Keep only last 10 searches
    if (searches.length > 10) {
      searches.removeRange(10, searches.length);
    }
    
    await saveData('recent_searches', jsonEncode(searches));
  }

  static Future<List<String>> getRecentSearches() async {
    final searchesJson = await getData('recent_searches');
    if (searchesJson != null) {
      return List<String>.from(jsonDecode(searchesJson));
    }
    return [];
  }

  static Future<void> clearRecentSearches() async {
    await removeData('recent_searches');
  }

  // App usage statistics
  static Future<void> recordAppUsage() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final usage = await getAppUsage();
    usage[today] = (usage[today] ?? 0) + 1;
    await saveData('app_usage', jsonEncode(usage));
  }

  static Future<Map<String, dynamic>> getAppUsage() async {
    final usageJson = await getData('app_usage');
    if (usageJson != null) {
      return Map<String, dynamic>.from(jsonDecode(usageJson));
    }
    return {};
  }

  // Export data for backup
  static Future<Map<String, dynamic>> exportAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final data = <String, dynamic>{};
    
    for (final key in allKeys) {
      data[key] = prefs.get(key);
    }
    
    return {
      'preferences': data,
      'secure_data_keys': ['auth_token', 'user_data'], // Don't export actual secure data
      'export_timestamp': DateTime.now().toIso8601String(),
      'app_version': '1.0.0',
    };
  }

  // Import data from backup
  static Future<void> importData(Map<String, dynamic> importData) async {
    final prefs = await SharedPreferences.getInstance();
    final preferences = importData['preferences'] as Map<String, dynamic>?;
    
    if (preferences != null) {
      for (final entry in preferences.entries) {
        final key = entry.key;
        final value = entry.value;
        
        // Skip secure data and system keys
        if (key.startsWith('flutter.') || key == 'auth_token' || key == 'user_data') {
          continue;
        }
        
        if (value is String) {
          await prefs.setString(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is List<String>) {
          await prefs.setStringList(key, value);
        }
      }
    }
  }
}