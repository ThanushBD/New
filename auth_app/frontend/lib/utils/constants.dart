class Constants {
  // ============== API CONFIGURATION ==============
  
  // Base URL for different environments
  // For Android Emulator
  static const String baseUrl = 'http://10.0.2.2:3000';
  // For iOS Simulator
  // static const String baseUrl = 'http://localhost:3000';
  // For Physical Device (replace with your computer's IP)
  // static const String baseUrl = 'http://192.168.1.100:3000';
  // For Production
  // static const String baseUrl = 'https://your-production-api.com';
  
  // API version
  static const String apiVersion = '/api';
  
  // Authentication endpoints
  static const String loginEndpoint = '$baseUrl$apiVersion/auth/login';
  static const String registerEndpoint = '$baseUrl$apiVersion/auth/register';
  static const String profileEndpoint = '$baseUrl$apiVersion/auth/profile';
  static const String forgotPasswordEndpoint = '$baseUrl$apiVersion/auth/forgot-password';
  static const String resetPasswordEndpoint = '$baseUrl$apiVersion/auth/reset-password';
  static const String googleAuthEndpoint = '$baseUrl$apiVersion/auth/google';
  static const String verifyEmailEndpoint = '$baseUrl$apiVersion/auth/verify-email';
  
  // Other endpoints
  static const String tasksEndpoint = '$baseUrl$apiVersion/tasks';
  static const String timesheetEndpoint = '$baseUrl$apiVersion/timesheet';
  
  // ============== EXTERNAL SERVICE CONFIGURATION ==============
  
  // Google Sign-In (Use your actual client ID here)
  static const String googleClientId = '397841208065-r4fkpq14e901mg92nr8ou72p8rbe0543.apps.googleusercontent.com';
  
  // ============== STORAGE KEYS ==============
  
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String settingsKey = 'app_settings';
  static const String cachePrefix = 'cache_';
  
  // ============== APP CONFIGURATION ==============
  
  static const String appName = 'TaskFlow';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Professional task management and time tracking';
  
  // ============== UI CONSTANTS ==============
  
  // Theme Colors
  static const int primaryColorValue = 0xFF667eea;
  static const int secondaryColorValue = 0xFF764ba2;
  static const int accentColorValue = 0xFF6B73FF;
  
  // Animation Durations
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  static const Duration extraSlowAnimation = Duration(milliseconds: 1000);
  
  // Layout
  static const double defaultPadding = 16.0;
  static const double largePadding = 24.0;
  static const double smallPadding = 8.0;
  static const double borderRadius = 12.0;
  static const double largeBorderRadius = 20.0;
  static const double buttonHeight = 48.0;
  static const double inputHeight = 56.0;
  
  // Typography
  static const double titleFontSize = 24.0;
  static const double headingFontSize = 20.0;
  static const double bodyFontSize = 16.0;
  static const double captionFontSize = 14.0;
  static const double smallFontSize = 12.0;
  
  // ============== TASK MANAGEMENT ==============
  
  // Task Priorities
  static const List<String> taskPriorities = ['low', 'medium', 'high', 'urgent'];
  static const List<String> taskPriorityLabels = ['Low', 'Medium', 'High', 'Urgent'];
  
  // Task Statuses
  static const List<String> taskStatuses = ['pending', 'in_progress', 'completed', 'cancelled'];
  static const List<String> taskStatusLabels = ['Pending', 'In Progress', 'Completed', 'Cancelled'];
  
  // Default Categories
  static const List<String> defaultCategories = [
    'Development',
    'Design',
    'Meeting',
    'Documentation',
    'Research',
    'Testing',
    'Marketing',
    'General'
  ];
  
  // Category Icons
  static const Map<String, String> categoryIcons = {
    'Development': 'code',
    'Design': 'palette',
    'Meeting': 'people',
    'Documentation': 'description',
    'Research': 'search',
    'Testing': 'bug_report',
    'Marketing': 'campaign',
    'General': 'folder',
  };
  
  // Category Colors
  static const Map<String, int> categoryColors = {
    'Development': 0xFF2196F3,
    'Design': 0xFF9C27B0,
    'Meeting': 0xFFFF9800,
    'Documentation': 0xFF4CAF50,
    'Research': 0xFF607D8B,
    'Testing': 0xFFF44336,
    'Marketing': 0xFFE91E63,
    'General': 0xFF667eea,
  };
  
  // ============== TIME TRACKING ==============
  
  // Timer intervals
  static const Duration timerUpdateInterval = Duration(seconds: 1);
  static const Duration autoSaveInterval = Duration(minutes: 5);
  
  // Default time settings
  static const int defaultTaskEstimateMinutes = 60;
  static const int dailyGoalMinutes = 480; // 8 hours
  static const int maxSessionMinutes = 480; // 8 hours
  
  // Time formats
  static const String timeFormat24 = 'HH:mm';
  static const String timeFormat12 = 'h:mm a';
  static const String dateFormat = 'MMM dd, yyyy';
  static const String dateTimeFormat = 'MMM dd, yyyy HH:mm';
  
  // ============== NETWORK CONFIGURATION ==============
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
  
  // Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Cache duration
  static const Duration shortCacheDuration = Duration(minutes: 5);
  static const Duration mediumCacheDuration = Duration(minutes: 30);
  static const Duration longCacheDuration = Duration(hours: 24);
  
  // ============== PAGINATION ==============
  
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  static const int recentItemsLimit = 10;
  
  // ============== VALIDATION ==============
  
  // Password requirements
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  
  // Task requirements
  static const int minTaskTitleLength = 1;
  static const int maxTaskTitleLength = 255;
  static const int maxTaskDescriptionLength = 2000;
  
  // Name requirements
  static const int minNameLength = 1;
  static const int maxNameLength = 100;
  
  // Email validation
  static const String emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  
  // ============== NOTIFICATION SETTINGS ==============
  
  // Notification types
  static const String notificationTypeTaskDue = 'task_due';
  static const String notificationTypeTaskOverdue = 'task_overdue';
  static const String notificationTypeTimerRunning = 'timer_running';
  static const String notificationTypeDailyGoal = 'daily_goal';
  
  // Default notification times
  static const List<int> defaultReminderMinutes = [5, 15, 30, 60]; // minutes before due date
  
  // ============== FEATURE FLAGS ==============
  
  static const bool enableOfflineMode = true;
  static const bool enablePushNotifications = true;
  static const bool enableAnalytics = false;
  static const bool enableBiometrics = true;
  static const bool enableDarkMode = true;
  
  // ============== ERROR MESSAGES ==============
  
  static const String networkErrorMessage = 'Network connection error. Please check your internet connection and try again.';
  static const String serverErrorMessage = 'Server error occurred. Please try again later.';
  static const String validationErrorMessage = 'Please check your input and try again.';
  static const String authErrorMessage = 'Authentication failed. Please login again.';
  static const String notFoundErrorMessage = 'The requested resource was not found.';
  static const String permissionErrorMessage = 'You do not have permission to perform this action.';
  
  // ============== SUCCESS MESSAGES ==============
  
  static const String taskCreatedMessage = 'Task created successfully!';
  static const String taskUpdatedMessage = 'Task updated successfully!';
  static const String taskDeletedMessage = 'Task deleted successfully!';
  static const String timerStartedMessage = 'Timer started!';
  static const String timerStoppedMessage = 'Timer stopped!';
  static const String dataRefreshedMessage = 'Data refreshed successfully!';
  
  // ============== ANALYTICS EVENTS ==============
  
  static const String eventAppOpened = 'app_opened';
  static const String eventTaskCreated = 'task_created';
  static const String eventTaskCompleted = 'task_completed';
  static const String eventTimerStarted = 'timer_started';
  static const String eventTimerStopped = 'timer_stopped';
  static const String eventUserRegistered = 'user_registered';
  static const String eventUserLoggedIn = 'user_logged_in';
  
  // ============== DEBUGGING ==============
  
  static const bool enableDebugMode = true; // Set to false in production
  static const bool enableApiLogging = true; // Set to false in production
  static const bool enablePerformanceLogging = false;
  
  // ============== FILE HANDLING ==============
  
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png', 'gif'];
  static const List<String> allowedDocumentExtensions = ['pdf', 'doc', 'docx', 'txt'];
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  
  // ============== SOCIAL LINKS ==============
  
  static const String supportEmail = 'support@taskflow.app';
  static const String privacyPolicyUrl = 'https://taskflow.app/privacy';
  static const String termsOfServiceUrl = 'https://taskflow.app/terms';
  static const String helpDocumentationUrl = 'https://docs.taskflow.app';
  
  // ============== GRADIENTS ==============
  
  static const List<int> primaryGradient = [0xFF667eea, 0xFF764ba2];
  static const List<int> secondaryGradient = [0xFF11998e, 0xFF38ef7d];
  static const List<int> warningGradient = [0xFFfc466b, 0xFF3f5efb];
  static const List<int> successGradient = [0xFF4CAF50, 0xFF45a049];
  static const List<int> dangerGradient = [0xFFF44336, 0xFFe53935];
  
  // ============== RESPONSIVE BREAKPOINTS ==============
  
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;
  static const double desktopBreakpoint = 1200.0;
  
  // ============== CHART CONFIGURATION ==============
  
  static const int maxWeeklyChartBars = 7;
  static const int maxMonthlyChartPoints = 30;
  static const int maxCategoryPieSlices = 8;
  
  // ============== SEARCH CONFIGURATION ==============
  
  static const int maxRecentSearches = 10;
  static const int minSearchLength = 2;
  static const Duration searchDebounceDelay = Duration(milliseconds: 500);
  
  // ============== BACKUP & SYNC ==============
  
  static const Duration syncInterval = Duration(minutes: 15);
  static const int maxSyncQueueSize = 100;
  static const Duration backupRetention = Duration(days: 30);
}