import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/task_service.dart';
import '../services/api_service.dart' hide TaskCreationData;
import '../models/user.dart';
import '../models/task.dart';
import '../models/timesheet.dart';
import '../models/task_creation_data.dart';
import 'login_screen.dart';
import '../widgets/enhanced_task_creation_dialog.dart' hide TaskCreationData;
import '../widgets/notification_bell.dart';
import '../screens/assignment_dashboard.dart';
import 'package:fl_chart/fl_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  User? _user;
  bool _isLoading = true;
  List<Task> _tasks = [];
  List<TimeEntry> _timeEntries = [];
  TimeEntry? _activeTimer;
  Map<String, dynamic> _statistics = {};
  int _selectedTabIndex = 0;

  late AnimationController _animationController;
  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late AnimationController _timerController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _timerAnimation;

  final PageController _pageController = PageController();

  bool _timerActionLoading = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadAllData();
    _startTimerUpdates();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _staggerController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _timerController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _staggerController,
      curve: Curves.elasticOut,
    ));

    _timerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_timerController);

    _timerController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fadeController.dispose();
    _staggerController.dispose();
    _timerController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimerUpdates() {
    // Update timer every second
    Stream.periodic(Duration(seconds: 1)).listen((_) {
      if (_activeTimer != null && _activeTimer!.isRunning) {
        setState(() {});
      }
    });
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = await StorageService.getUser();
      final tasks = await TaskService.getTasks(useCache: false); 
      final timeEntries = await TaskService.getTimeEntries(useCache: false); 
      final activeTimer = await TaskService.getActiveTimer(); 
      final statistics = await TaskService.getTaskStatistics(useCache: false); 

      if (mounted) {
        setState(() {
          _user = user;
          _tasks = tasks;
          _timeEntries = timeEntries;
          _activeTimer = activeTimer;
          _statistics = statistics;
          _isLoading = false;
        });

        // Start animations after data loads
        _fadeController.forward();
        await Future.delayed(Duration(milliseconds: 200));
        _animationController.forward();
        await Future.delayed(Duration(milliseconds: 300));
        _staggerController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load data');
      }
    }
  }

  Future<void> _refreshData() async {
    HapticFeedback.lightImpact();
    
    try {
      await _loadAllData();
      if (mounted) {
        _showSuccessSnackBar('Data refreshed successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to refresh data');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _logout() async {
    HapticFeedback.lightImpact();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _buildLogoutDialog(),
    );

    if (result == true && mounted) {
      HapticFeedback.heavyImpact();
      
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                ),
                SizedBox(height: 16),
                Text('Signing out...'),
              ],
            ),
          ),
        ),
      );

      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(-1.0, 0.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
          ),
        );
      }
    }
  }

  Future<void> _toggleTaskStatus(String taskId) async {
    try {
      HapticFeedback.selectionClick();
      await TaskService.toggleTaskStatus(taskId);
      await _loadAllData();
      _showSuccessSnackBar('Task updated!');
    } catch (e) {
      _showErrorSnackBar('Failed to update task');
    }
  }

  Future<void> _deleteTask(String taskId) async {
    try {
      HapticFeedback.lightImpact();
      await TaskService.deleteTask(taskId);
      await _loadAllData();
      _showSuccessSnackBar('Task deleted!');
    } catch (e) {
      _showErrorSnackBar('Failed to delete task');
    }
  }

  Future<void> _toggleTimer(Task task) async {
    try {
      HapticFeedback.lightImpact();
      if (_activeTimer != null && _activeTimer!.isRunning) {
        await TaskService.pauseTimer();
        _showSuccessSnackBar('Timer paused!');
      } else if (_activeTimer != null && !_activeTimer!.isRunning && _activeTimer!.taskId == task.id) {
        await TaskService.startTimer(task.id, task.title, task.category);
        _showSuccessSnackBar('Timer resumed!');
      } else {
        await TaskService.startTimer(task.id, task.title, task.category);
        _showSuccessSnackBar('Timer started!');
      }
      await _loadAllData();
    } catch (e) {
      _showErrorSnackBar('Failed to toggle timer');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFF6B73FF),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildCustomAppBar(),
              ),

              // Tab Bar
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildTabBar(),
              ),

              // Main Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _selectedTabIndex = index);
                  },
                  children: [
                    _buildDashboardPage(),
                    _buildTasksPage(),
                    _buildTimesheetPage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _selectedTabIndex == 1
          ? _buildFloatingActionButton()
          : null,
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFF6B73FF),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Loading your workspace...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TaskFlow',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Welcome back, ${_user?.firstName ?? 'User'}!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Active Timer Indicator
              if (_activeTimer != null && _activeTimer!.isRunning)
                Container(
                  margin: EdgeInsets.only(right: 12),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _timerAnimation,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        _activeTimer!.durationString,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Assignment Dashboard Button
              Container(
                margin: EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.assignment, color: Colors.white),
                  onPressed: _navigateToAssignmentDashboard,
                  tooltip: 'Task Assignments',
                ),
              ),
              
              // Notification Bell
              if (_user != null)
                NotificationBell(currentUser: _user!),
              
              // Logout Button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.logout, color: Colors.white),
                  onPressed: _logout,
                  tooltip: 'Logout',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildTabItem('Dashboard', 0, Icons.dashboard),
          _buildTabItem('Tasks', 1, Icons.task_alt),
          _buildTabItem('Timesheet', 2, Icons.access_time),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedTabIndex = index);
          _pageController.animateToPage(
            index,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Color(0xFF667eea) : Colors.white.withValues(alpha: 0.7),
                size: 18,
              ),
              SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Color(0xFF667eea) : Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAssignmentDashboard() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            AssignmentDashboard(currentUser: _user!),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildDashboardPage() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Color(0xFF667eea),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Card
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildUserProfileCard(),
                ),
              ),

              SizedBox(height: 24),

              // Enhanced Statistics Cards with Assignment Info
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildStatisticsCards(), // This now includes assignment stats
                ),
              ),

              SizedBox(height: 24),

              // New: Real-time Workload Bar Chart
              _buildWeeklyWorkloadChart(),

              SizedBox(height: 24),

              // Enhanced Recent Tasks with Assignment Info
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildEnhancedRecentTasks(), // This now shows assignment info
                ),
              ),

              SizedBox(height: 24),

              // Time Tracking Summary
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildTimeTrackingSummary(),
                ),
              ),

              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedRecentTasks() {
    final recentTasks = _tasks.take(3).toList();
    
    if (recentTasks.isEmpty) {
      return Container();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Tasks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _navigateToAssignmentDashboard,
                      child: Text(
                        'Assignments',
                        style: TextStyle(color: Color(0xFF667eea)),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedTabIndex = 1);
                        _pageController.animateToPage(1, 
                          duration: Duration(milliseconds: 300), 
                          curve: Curves.easeInOut);
                      },
                      child: Text(
                        'View All',
                        style: TextStyle(color: Color(0xFF667eea)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            ...recentTasks.map((task) => _buildEnhancedTaskListItem(task)),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedTaskListItem(Task task) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: task.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: task.statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: task.priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                        decoration: task.status == TaskStatus.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: task.statusColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            task.statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          task.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (task.estimatedHours > 0) ...[
                          SizedBox(width: 8),
                          Icon(Icons.schedule, size: 12, color: Colors.grey.shade500),
                          SizedBox(width: 2),
                          Text(
                            '${task.estimatedHours}h',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(
                    task.status == TaskStatus.completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: task.statusColor,
                    size: 20,
                  ),
                  if (task.dueDate != null) ...[
                    SizedBox(height: 4),
                    Text(
                      '${task.dueDate!.day}/${task.dueDate!.month}',
                      style: TextStyle(
                        fontSize: 10,
                        color: task.isOverdue ? Colors.red : Colors.grey.shade500,
                        fontWeight: task.isOverdue ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTasksPage() {
    final pendingTasks = _tasks.where((t) => t.status != TaskStatus.completed).toList();
    final completedTasks = _tasks.where((t) => t.status == TaskStatus.completed).toList();

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Color(0xFF667eea),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Active Timer Card
              if (_activeTimer != null && _activeTimer!.isRunning)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildActiveTimerCard(),
                ),

              if (_activeTimer != null && _activeTimer!.isRunning)
                SizedBox(height: 20),

              // Pending Tasks
              if (pendingTasks.isNotEmpty) ...[
                Text(
                  'Active Tasks (${pendingTasks.length})',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
                ...pendingTasks.map((task) => _buildTaskCard(task)),
                SizedBox(height: 24),
              ],

              // Completed Tasks
              if (completedTasks.isNotEmpty) ...[
                Text(
                  'Completed Tasks (${completedTasks.length})',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
                ...completedTasks.map((task) => _buildTaskCard(task)),
              ],

              if (_tasks.isEmpty)
                _buildEmptyTasksWidget(),

              SizedBox(height: 100), // Space for FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimesheetPage() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Color(0xFF667eea),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Today's Time Summary
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildTodayTimeSummary(),
              ),

              SizedBox(height: 24),

              // Weekly Overview
              SlideTransition(
                position: _slideAnimation,
                child: _buildWeeklyTimeChart(),
              ),

              SizedBox(height: 24),

              // Recent Time Entries
              ScaleTransition(
                scale: _scaleAnimation,
                child: _buildRecentTimeEntries(),
              ),

              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfileCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF667eea).withOpacity(0.3),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 35,
                backgroundColor: Colors.transparent,
                child: _user?.avatarUrl != null
                    ? ClipOval(
                        child: Image.network(
                          _user!.avatarUrl!,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar();
                          },
                        ),
                      )
                    : _buildDefaultAvatar(),
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _user?.fullName ?? 'User',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _user?.email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF667eea).withOpacity(0.1), Color(0xFF764ba2).withOpacity(0.1)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Productivity Pro',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF667eea),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.verified,
              color: Colors.green,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Text(
      _user?.initials ?? 'U',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return FutureBuilder<Map<String, dynamic>>(
      future: TaskService.getTaskStatistics(useCache: false),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            // First row - Basic task counts
            Row(
              children: [
                Expanded(child: _buildStatCard(
                  'Total Tasks',
                  stats['total_tasks']?.toString() ?? '0',
                  Icons.task_alt,
                  Colors.blue,
                )),
                SizedBox(width: 12),
                Expanded(child: _buildStatCard(
                  'Completed',
                  stats['completed_tasks']?.toString() ?? '0',
                  Icons.check_circle,
                  Colors.green,
                )),
              ],
            ),
            SizedBox(height: 12),
            // Second row - Progress and assignments
            Row(
              children: [
                Expanded(child: _buildStatCard(
                  'In Progress',
                  stats['in_progress_tasks']?.toString() ?? '0',
                  Icons.play_circle,
                  Colors.orange,
                )),
                SizedBox(width: 12),
                Expanded(child: _buildStatCard(
                  'Assigned to Me',
                  stats['assignedToMe']?.toString() ?? '0',
                  Icons.person,
                  Colors.purple,
                )),
              ],
            ),
            SizedBox(height: 12),
            // Third row - Time and assignments created
            Row(
              children: [
                Expanded(child: _buildStatCard(
                  'Time Today',
                  stats['totalTimeTodayString'] ?? '0h 0m',
                  Icons.access_time,
                  Colors.indigo,
                )),
                SizedBox(width: 12),
                Expanded(child: _buildStatCard(
                  'Assigned by Me',
                  stats['assignedByMe']?.toString() ?? '0',
                  Icons.assignment_ind,
                  Colors.teal,
                )),
              ],
            ),
            SizedBox(height: 12),
            // New: Overdue, Due Today, Active Timers
            FutureBuilder<List<Task>>(
              future: TaskService.getTasks(useCache: false),
              builder: (context, taskSnap) {
                final tasks = taskSnap.data ?? [];
                final now = DateTime.now();
                final overdue = tasks.where((t) => t.dueDate != null && t.dueDate!.isBefore(now) && t.status != TaskStatus.completed).length;
                final dueToday = tasks.where((t) => t.dueDate != null && t.dueDate!.day == now.day && t.dueDate!.month == now.month && t.dueDate!.year == now.year).length;
                final completionRate = (stats['total_tasks'] != null && stats['total_tasks'] > 0)
                  ? (((stats['completed_tasks'] ?? 0) / stats['total_tasks']) * 100).toStringAsFixed(1) + '%'
                  : '0%';
                return Row(
                  children: [
                    Expanded(child: _buildStatCard(
                      'Overdue Tasks',
                      overdue.toString(),
                      Icons.warning,
                      Colors.red,
                    )),
                    SizedBox(width: 12),
                    Expanded(child: _buildStatCard(
                      'Due Today',
                      dueToday.toString(),
                      Icons.today,
                      Colors.deepOrange,
                    )),
                  ],
                );
              },
            ),
            SizedBox(height: 12),
            FutureBuilder<List<TimeEntry>>(
              future: TaskService.getTimeEntries(useCache: false),
              builder: (context, timeSnap) {
                final entries = timeSnap.data ?? [];
                final activeTimers = entries.where((e) => e.isRunning).length;
                return Row(
                  children: [
                    Expanded(child: _buildStatCard(
                      'Active Timers',
                      activeTimers.toString(),
                      Icons.timer,
                      Colors.pink,
                    )),
                    SizedBox(width: 12),
                    Expanded(child: _buildStatCard(
                      'Completion Rate',
                      (stats['total_tasks'] != null && stats['total_tasks'] > 0)
                        ? (((stats['completed_tasks'] ?? 0) / stats['total_tasks']) * 100).toStringAsFixed(1) + '%'
                        : '0%',
                      Icons.percent,
                      Colors.blueGrey,
                    )),
                  ],
                );
              },
            ),
            SizedBox(height: 12),
            // New: Total Time This Week
            FutureBuilder<List<Map<String, dynamic>>>(
              future: ApiService.getWeeklyStats(),
              builder: (context, weekSnap) {
                final weekStats = weekSnap.data ?? [];
                final totalMinutes = weekStats.fold<int>(0, (sum, stat) {
                  final total = stat['total_minutes'];
                  if (total is int) return sum + total;
                  if (total is String) return sum + (int.tryParse(total) ?? 0);
                  if (total is num) return sum + total.toInt();
                  return sum;
                });
                return Row(
                  children: [
                    Expanded(child: _buildStatCard(
                      'Time This Week',
                      '${(totalMinutes ~/ 60)}h ${(totalMinutes % 60)}m',
                      Icons.calendar_today,
                      Colors.deepPurple,
                    )),
                    SizedBox(width: 12),
                    // Most Worked Category Today
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: ApiService.getTimeByCategory(
                        startDate: DateTime.now(),
                        endDate: DateTime.now(),
                      ),
                      builder: (context, catSnap) {
                        final cats = catSnap.data ?? [];
                        String mostCat = 'None';
                        int mostMin = 0;
                        for (final c in cats) {
                          final int min = c['total_minutes'] is int
                            ? c['total_minutes']
                            : int.tryParse(c['total_minutes'].toString()) ?? 0;
                          if (min > mostMin) {
                            mostMin = min;
                            mostCat = c['category'] ?? 'Unknown';
                          }
                        }
                        return Expanded(child: _buildStatCard(
                          'Top Category Today',
                          mostCat,
                          Icons.category,
                          Colors.amber,
                        ));
                      },
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 12),
            // New: Pie chart for today's category breakdown
            FutureBuilder<List<Map<String, dynamic>>>(
              future: ApiService.getTimeByCategory(
                startDate: DateTime.now(),
                endDate: DateTime.now(),
              ),
              builder: (context, catSnap) {
                final cats = catSnap.data ?? [];
                final total = cats.fold<int>(0, (sum, c) {
                  final int min = c['total_minutes'] is int
                    ? c['total_minutes']
                    : int.tryParse(c['total_minutes'].toString()) ?? 0;
                  return sum + min;
                });
                if (cats.isEmpty || total == 0) {
                  return Container();
                }
                return SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sections: cats.map((c) {
                        final min = c['total_minutes'] is int
                          ? c['total_minutes']
                          : int.tryParse(c['total_minutes'].toString()) ?? 0;
                        final percent = total > 0 ? (min / total) * 100 : 0.0;
                        return PieChartSectionData(
                          value: min.toDouble(),
                          title: '${c['category'] ?? 'Unknown'}\n${min}m',
                          color: Colors.primaries[cats.indexOf(c) % Colors.primaries.length],
                          radius: 60,
                          titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTrackingSummary() {
    final todayEntries = _timeEntries.where((e) => 
        e.startTime.day == DateTime.now().day &&
        e.startTime.month == DateTime.now().month &&
        e.startTime.year == DateTime.now().year
    ).toList();

    final totalTime = todayEntries.fold<Duration>(
      Duration.zero, 
      (total, entry) => total + entry.elapsedDuration,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today\'s Time Log',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  '${totalTime.inHours}h ${totalTime.inMinutes.remainder(60)}m',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF667eea),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (todayEntries.isNotEmpty) ...[
              ...todayEntries.take(3).map((entry) => Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color(0xFF667eea),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.taskTitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Text(
                      entry.durationString,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )),
            ] else
              Text(
                'No time entries for today',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTimerCard() {
    if (_activeTimer == null) return Container();
    final isRunning = _activeTimer!.isRunning;
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: _timerAnimation,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                isRunning ? 'TRACKING TIME' : 'TIMER PAUSED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            _activeTimer!.taskTitle,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _activeTimer!.durationString,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              Row(
                children: [
                  if (isRunning)
                    IconButton(
                      onPressed: _timerActionLoading ? null : () async {
                        setState(() => _timerActionLoading = true);
                        await TaskService.pauseTimer();
                        await _loadAllData();
                        setState(() => _timerActionLoading = false);
                        _showSuccessSnackBar('Timer paused!');
                      },
                      icon: _timerActionLoading
                        ? SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : Icon(Icons.pause_circle, color: Colors.white, size: 32),
                    ),
                  if (!isRunning)
                    IconButton(
                      onPressed: _timerActionLoading ? null : () async {
                        setState(() => _timerActionLoading = true);
                        await TaskService.startTimer(_activeTimer!.taskId, _activeTimer!.taskTitle, _activeTimer!.category);
                        await _loadAllData();
                        setState(() => _timerActionLoading = false);
                        _showSuccessSnackBar('Timer resumed!');
                      },
                      icon: _timerActionLoading
                        ? SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : Icon(Icons.play_circle, color: Colors.white, size: 32),
                    ),
                  IconButton(
                    onPressed: _timerActionLoading ? null : () async {
                      setState(() => _timerActionLoading = true);
                      await TaskService.stopTimer();
                      await _loadAllData();
                      setState(() => _timerActionLoading = false);
                      _showSuccessSnackBar('Timer stopped!');
                    },
                    icon: _timerActionLoading
                      ? SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : Icon(Icons.stop_circle, color: Colors.white, size: 32),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    return FutureBuilder<Duration>(
      future: TaskService.getTimeSpentForTask(task.id),
      builder: (context, snapshot) {
        final timeSpent = snapshot.data ?? Duration.zero;
        return Container(
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                          decoration: task.status == TaskStatus.completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        switch (value) {
                          case 'toggle':
                            await _toggleTaskStatus(task.id);
                            break;
                          case 'timer':
                            await _toggleTimer(task);
                            break;
                          case 'delete':
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Delete Task'),
                                content: Text('Are you sure you want to delete this task?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _deleteTask(task.id);
                            }
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(
                                task.status == TaskStatus.completed
                                    ? Icons.restart_alt
                                    : Icons.check_circle,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(task.status == TaskStatus.completed
                                  ? 'Mark Incomplete'
                                  : 'Mark Complete'),
                            ],
                          ),
                        ),
                        if (task.status != TaskStatus.completed)
                          PopupMenuItem(
                            value: 'timer',
                            child: Row(
                              children: [
                                Icon(
                                  _activeTimer?.taskId == task.id && _activeTimer!.isRunning
                                      ? Icons.stop
                                      : Icons.play_arrow,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(_activeTimer?.taskId == task.id && _activeTimer!.isRunning
                                    ? 'Stop Timer'
                                    : 'Start Timer'),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (task.description.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(
                    task.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: task.priorityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: task.priorityColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        task.priorityLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: task.priorityColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: task.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: task.statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        task.statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: task.statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Spacer(),
                    if (task.dueDate != null)
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: task.isOverdue ? Colors.red : Colors.grey.shade600,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${task.dueDate!.day}/${task.dueDate!.month}',
                            style: TextStyle(
                              fontSize: 12,
                              color: task.isOverdue ? Colors.red : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (task.category.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(
                    task.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                // Time spent UI
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Color(0xFF667eea)),
                    SizedBox(width: 4),
                    Text(
                      'Time Spent: ${timeSpent.inHours}h ${timeSpent.inMinutes.remainder(60)}m',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF667eea),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyTasksWidget() {
    return Container(
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          Icon(
            Icons.task_alt,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'No tasks yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tap the + button to create your first task',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTimeSummary() {
    final todayEntries = _timeEntries.where((e) => 
        e.startTime.day == DateTime.now().day &&
        e.startTime.month == DateTime.now().month &&
        e.startTime.year == DateTime.now().year
    ).toList();

    final totalTime = todayEntries.fold<Duration>(
      Duration.zero, 
      (total, entry) => total + entry.elapsedDuration,
    );

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Total',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '${totalTime.inHours}h ${totalTime.inMinutes.remainder(60)}m',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sessions',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      todayEntries.length.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Average',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      todayEntries.isNotEmpty
                          ? '${(totalTime.inMinutes / todayEntries.length).round()}m'
                          : '0m',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTimeChart() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Week',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _buildWeeklyBars(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWeeklyBars() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final List<Widget> bars = [];

    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().subtract(Duration(days: 6 - i));
      final dayEntries = _timeEntries.where((e) => 
          e.startTime.day == date.day &&
          e.startTime.month == date.month &&
          e.startTime.year == date.year
      ).toList();

      final totalMinutes = dayEntries.fold<int>(
        0, 
        (total, entry) => total + entry.elapsedDuration.inMinutes,
      );

      final maxMinutes = 480; // 8 hours
      final height = (totalMinutes / maxMinutes * 60).clamp(4.0, 60.0);

      bars.add(
        Column(
          children: [
            Container(
              width: 20,
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            SizedBox(height: 8),
            Text(
              days[i],
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return bars;
  }

  Widget _buildRecentTimeEntries() {
    final recentEntries = _timeEntries.take(5).toList();

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Time Entries',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 16),
          if (recentEntries.isNotEmpty) ...[
            ...recentEntries.map((entry) => Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(0xFF667eea),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.taskTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          entry.formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    entry.durationString,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF667eea),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            )),
          ] else
            Text(
              'No time entries yet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _showEnhancedTaskDialog,
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: Icon(Icons.assignment_ind, color: Colors.white, size: 24),
        label: Text(
          'Assign Task',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showEnhancedTaskDialog() {
    HapticFeedback.lightImpact();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EnhancedTaskCreationDialog(
        currentUser: _user!,
        onTaskCreated: (taskData) {
          _createTaskWithAssignment(taskData);
        },
      ),
    );
  }

  Future<void> _createTaskWithAssignment(TaskCreationData taskData) async {
    try {
      HapticFeedback.lightImpact();
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                ),
                SizedBox(height: 16),
                Text('Creating and assigning task...'),
              ],
            ),
          ),
        ),
      );

      await TaskService.createTaskWithAssignment(taskData);
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        await _loadAllData(); // Refresh data
        
        _showSuccessSnackBar(
          'Task "${taskData.title}" assigned to ${taskData.assignedTo.fullName}!'
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showErrorSnackBar('Failed to create task: ${e.toString()}');
      }
    }
  }

  Widget _buildLogoutDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF667eea).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.logout,
                color: Color(0xFF667eea),
                size: 32,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Sign Out',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Are you sure you want to sign out of your account?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Sign Out',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyWorkloadChart() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ApiService.getWeeklyStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        final weekStats = snapshot.data!;
        final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        final now = DateTime.now();
        List<int> minutes = List.filled(7, 0);
        for (final stat in weekStats) {
          final date = DateTime.parse(stat['date']);
          final weekday = date.weekday % 7; // Monday=1, Sunday=7->0
          final total = stat['total_minutes'];
          int minVal;
          if (total is int) {
            minVal = total;
          } else if (total is String) {
            minVal = int.tryParse(total) ?? 0;
          } else if (total is num) {
            minVal = total.toInt();
          } else {
            minVal = 0;
          }
          minutes[weekday == 0 ? 6 : weekday - 1] = minVal;
        }
        final maxMinutes = (minutes.reduce((a, b) => a > b ? a : b)).clamp(60, 480);
        return Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workload This Week',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxMinutes.toDouble(),
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            return Text('${value.toInt()}m', style: TextStyle(fontSize: 10));
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            return Text(days[idx], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600));
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(7, (i) {
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: minutes[i].toDouble(),
                            color: Color(0xFF667eea),
                            width: 18,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}