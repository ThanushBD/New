import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/services/task_service.dart';
import 'package:frontend/models/notification.dart';

// Notification Bell Widget for App Bar
class NotificationBell extends StatefulWidget {
  final User currentUser;

  const NotificationBell({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  _NotificationBellState createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with TickerProviderStateMixin {
  List<TaskNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  late AnimationController _bellAnimation;
  late AnimationController _badgeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadNotifications();
    _startPeriodicCheck();
  }

  void _setupAnimations() {
    _bellAnimation = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    
    _badgeAnimation = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _bellAnimation.dispose();
    _badgeAnimation.dispose();
    super.dispose();
  }

  void _startPeriodicCheck() {
    // Check for new notifications every 30 seconds
    Stream.periodic(Duration(seconds: 30)).listen((_) {
      if (mounted) {
        _loadNotifications();
      }
    });
  }

  Future<void> _loadNotifications() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final notifications = await TaskService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _unreadCount = notifications.where((n) => !n.isRead).length;
      });
    } catch (e) {
      // Handle error silently for background updates
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showNotificationsPanel() {
    HapticFeedback.selectionClick();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NotificationsPanel(
        notifications: _notifications,
        onNotificationRead: _markAsRead,
        onRefresh: _loadNotifications,
      ),
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await TaskService.markNotificationAsRead(notificationId);
      await _loadNotifications();
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RotationTransition(
          turns: Tween(begin: 0.0, end: 0.1)
              .chain(CurveTween(curve: Curves.elasticInOut))
              .animate(_bellAnimation),
          child: IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: 24,
            ),
            onPressed: _showNotificationsPanel,
          ),
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: ScaleTransition(
              scale: _badgeAnimation,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                constraints: BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Notifications Panel
class NotificationsPanel extends StatefulWidget {
  final List<TaskNotification> notifications;
  final Function(String) onNotificationRead;
  final VoidCallback onRefresh;

  const NotificationsPanel({
    Key? key,
    required this.notifications,
    required this.onNotificationRead,
    required this.onRefresh,
  }) : super(key: key);

  @override
  _NotificationsPanelState createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanel>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _slideController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildNotificationsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Notifications',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onRefresh,
            icon: Icon(Icons.refresh, color: Colors.white),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    if (widget.notifications.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      color: Color(0xFF667eea),
      child: ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: widget.notifications.length,
        separatorBuilder: (context, index) => SizedBox(height: 8),
        itemBuilder: (context, index) {
          final notification = widget.notifications[index];
          return _buildNotificationCard(notification, index);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You\'ll see task assignments and updates here',
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

  Widget _buildNotificationCard(TaskNotification notification, int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Card(
        elevation: notification.isRead ? 1 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (!notification.isRead) {
              widget.onNotificationRead(notification.id);
            }
          },
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: notification.isRead
                  ? null
                  : LinearGradient(
                      colors: [
                        Color(0xFF667eea).withOpacity(0.05),
                        Color(0xFF764ba2).withOpacity(0.05),
                      ],
                    ),
              border: notification.isRead
                  ? null
                  : Border.all(
                      color: Color(0xFF667eea).withOpacity(0.2),
                      width: 1,
                    ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getNotificationColor(notification.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getNotificationIcon(notification.type),
                    color: _getNotificationColor(notification.type),
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                          if (notification.isRead == false)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Color(0xFF667eea).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _formatTimeAgo(notification.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'task_assigned':
        return Icons.assignment_ind;
      case 'task_reassigned':
        return Icons.swap_horiz;
      case 'task_completed':
        return Icons.check_circle;
      case 'task_due_soon':
        return Icons.schedule;
      case 'task_overdue':
        return Icons.warning;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'task_assigned':
        return Colors.blue;
      case 'task_reassigned':
        return Colors.orange;
      case 'task_completed':
        return Colors.green;
      case 'task_due_soon':
        return Colors.amber;
      case 'task_overdue':
        return Colors.red;
      default:
        return Color(0xFF667eea);
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}