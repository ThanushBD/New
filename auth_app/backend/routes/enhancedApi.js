const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const pool = require('../config/database');
const Task = require('../models/Task');
const TimeEntry = require('../models/TimeEntry');

// Enhanced API service that combines task management and assignments
class EnhancedAPIService {
  
  // Get comprehensive dashboard data
  static async getDashboardData(req, res) {
    try {
      const userId = req.user.id;
      
      const [
        tasks,
        statistics,
        recentTasks,
        upcomingTasks,
        notifications,
        activeTimer,
        todayTime
      ] = await Promise.all([
        Task.findByUserId(userId, { limit: 10, includeAssigned: true }),
        this.getEnhancedStatistics(userId),
        Task.getRecentTasks(userId, 5),
        Task.getUpcomingTasks(userId, 7),
        this.getNotifications(userId, 10),
        TimeEntry.getActiveTimer(userId),
        TimeEntry.getTodayStats(userId)
      ]);

      res.json({
        success: true,
        data: {
          tasks,
          statistics,
          recentTasks,
          upcomingTasks,
          notifications,
          activeTimer,
          todayTime
        }
      });
    } catch (error) {
      console.error('Dashboard data error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to load dashboard data',
        error: error.message
      });
    }
  }

  // Get enhanced statistics including assignment data
  static async getEnhancedStatistics(userId) {
    const result = await pool.query(
      'SELECT * FROM get_enhanced_task_statistics($1)',
      [userId]
    );
    return result.rows[0];
  }

  // Get notifications with task details
  static async getNotifications(userId, limit = 50) {
    const result = await pool.query(
      'SELECT * FROM get_user_notifications($1, $2)',
      [userId, limit]
    );
    return result.rows;
  }

  // Create task with enhanced assignment support
  static async createTaskWithAssignment(req, res) {
    try {
      const userId = req.user.id;
      const {
        title,
        description,
        priority = 'medium',
        category = 'General',
        tags = [],
        estimatedHours = 1,
        startDate,
        dueDate,
        assignedTo
      } = req.body;

      if (!title || title.trim().length === 0) {
        return res.status(400).json({
          success: false,
          message: 'Task title is required'
        });
      }

      let task;
      
      if (assignedTo && assignedTo !== userId) {
        // Create task with assignment
        const result = await pool.query(
          'SELECT * FROM create_task_with_assignment($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)',
          [
            userId,
            title.trim(),
            description || '',
            userId, // assigned_by
            assignedTo, // assigned_to
            priority,
            category,
            estimatedHours,
            startDate ? new Date(startDate) : null,
            dueDate ? new Date(dueDate) : null,
            tags
          ]
        );

        if (!result.rows[0].success) {
          return res.status(400).json({
            success: false,
            message: result.rows[0].message
          });
        }

        // Get the created task with full details
        task = await Task.findById(result.rows[0].task_id, userId);
      } else {
        // Create regular task
        task = await Task.create({
          userId,
          title: title.trim(),
          description: description || '',
          priority,
          category,
          tags,
          estimatedHours,
          estimatedMinutes: estimatedHours * 60,
          dueDate: dueDate ? new Date(dueDate) : null,
          startDate: startDate ? new Date(startDate) : null
        });
      }

      res.status(201).json({
        success: true,
        data: task,
        message: assignedTo && assignedTo !== userId ? 
          'Task created and assigned successfully' : 
          'Task created successfully'
      });
    } catch (error) {
      console.error('Create task error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to create task',
        error: error.message
      });
    }
  }

  // Get available users for assignment
  static async getAvailableUsers(req, res) {
    try {
      const userId = req.user.id;
      
      const result = await pool.query(
        'SELECT * FROM get_available_users($1)',
        [userId]
      );
      
      res.json({
        success: true,
        data: result.rows,
        users: result.rows // For compatibility
      });
    } catch (error) {
      console.error('Error getting available users:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get available users',
        error: error.message
      });
    }
  }

  // Get task with full assignment details
  static async getTaskDetails(req, res) {
    try {
      const userId = req.user.id;
      const { taskId } = req.params;

      const task = await Task.findById(taskId, userId);
      if (!task) {
        return res.status(404).json({
          success: false,
          message: 'Task not found'
        });
      }

      // Get assignment details if task is assigned
      let assignmentDetails = null;
      if (task.assigned_to) {
        const assignmentResult = await pool.query(`
          SELECT ta.*, 
                 assignee.first_name as assignee_first_name,
                 assignee.last_name as assignee_last_name,
                 assignee.email as assignee_email,
                 assignee.avatar_url as assignee_avatar,
                 assigner.first_name as assigner_first_name,
                 assigner.last_name as assigner_last_name,
                 assigner.email as assigner_email
          FROM task_assignments ta
          LEFT JOIN users assignee ON ta.assigned_to = assignee.id
          LEFT JOIN users assigner ON ta.assigned_by = assigner.id
          WHERE ta.task_id = $1
          ORDER BY ta.assigned_at DESC
          LIMIT 1
        `, [taskId]);
        
        assignmentDetails = assignmentResult.rows[0] || null;
      }

      // Get time entries for this task
      const timeEntries = await TimeEntry.findByUserId(userId, { taskId });

      res.json({
        success: true,
        data: {
          task,
          assignmentDetails,
          timeEntries
        }
      });
    } catch (error) {
      console.error('Get task details error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get task details',
        error: error.message
      });
    }
  }

  // Update task assignment status
  static async updateAssignmentStatus(req, res) {
    try {
      const userId = req.user.id;
      const { taskId } = req.params;
      const { status, notes } = req.body;

      if (!['accepted', 'declined'].includes(status)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid assignment status'
        });
      }

      // Verify user is assigned to this task
      const task = await Task.findById(taskId, userId);
      if (!task || task.assigned_to !== userId) {
        return res.status(403).json({
          success: false,
          message: 'Not authorized to update this assignment'
        });
      }

      // Update assignment status
      await pool.query(`
        UPDATE task_assignments 
        SET status = $1, 
            accepted_at = $2,
            notes = $3
        WHERE task_id = $4 AND assigned_to = $5
      `, [
        status,
        status === 'accepted' ? new Date() : null,
        notes || null,
        taskId,
        userId
      ]);

      // Create notification for assigner
      await pool.query(`
        INSERT INTO notifications (user_id, task_id, type, title, message)
        VALUES ($1, $2, $3, $4, $5)
      `, [
        task.assigned_by,
        taskId,
        'assignment_' + status,
        `Task Assignment ${status.charAt(0).toUpperCase() + status.slice(1)}`,
        `${req.user.first_name} ${req.user.last_name} has ${status} the task: ${task.title}`
      ]);

      res.json({
        success: true,
        message: `Assignment ${status} successfully`
      });
    } catch (error) {
      console.error('Update assignment status error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to update assignment status',
        error: error.message
      });
    }
  }

  // Mark notification as read
  static async markNotificationAsRead(req, res) {
    try {
      const { notificationId } = req.params;
      const userId = req.user.id;

      await pool.query(
        'UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2',
        [notificationId, userId]
      );

      res.json({
        success: true,
        message: 'Notification marked as read'
      });
    } catch (error) {
      console.error('Mark notification error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to mark notification as read',
        error: error.message
      });
    }
  }

  // Get user profile with task statistics
  static async getUserProfile(req, res) {
    try {
      const userId = req.user.id;
      
      const [statistics, recentActivity] = await Promise.all([
        this.getEnhancedStatistics(userId),
        this.getRecentActivity(userId)
      ]);

      res.json({
        success: true,
        data: {
          user: {
            id: req.user.id,
            email: req.user.email,
            firstName: req.user.first_name,
            lastName: req.user.last_name,
            fullName: `${req.user.first_name} ${req.user.last_name}`,
            emailVerified: req.user.email_verified,
            avatarUrl: req.user.avatar_url
          },
          statistics,
          recentActivity
        }
      });
    } catch (error) {
      console.error('Get user profile error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get user profile',
        error: error.message
      });
    }
  }

  // Get recent activity for user
  static async getRecentActivity(userId) {
    const result = await pool.query(`
      SELECT 
        'task_completed' as type,
        t.title as title,
        t.completed_at as timestamp,
        'Completed task' as description
      FROM tasks t
      WHERE (t.user_id = $1 OR t.assigned_to = $1)
      AND t.status = 'completed'
      AND t.completed_at >= CURRENT_TIMESTAMP - INTERVAL '7 days'
      
      UNION ALL
      
      SELECT 
        'time_logged' as type,
        te.task_title as title,
        te.end_time as timestamp,
        CONCAT('Logged ', ROUND(te.duration_minutes), ' minutes') as description
      FROM time_entries te
      WHERE te.user_id = $1
      AND te.end_time IS NOT NULL
      AND te.end_time >= CURRENT_TIMESTAMP - INTERVAL '7 days'
      
      ORDER BY timestamp DESC
      LIMIT 20
    `, [userId]);
    
    return result.rows;
  }
}

// Routes
router.get('/dashboard', authenticateToken, EnhancedAPIService.getDashboardData);
router.post('/tasks/create', authenticateToken, EnhancedAPIService.createTaskWithAssignment);
router.get('/tasks/users/available', authenticateToken, EnhancedAPIService.getAvailableUsers);
router.get('/tasks/:taskId/details', authenticateToken, EnhancedAPIService.getTaskDetails);
router.patch('/tasks/:taskId/assignment', authenticateToken, EnhancedAPIService.updateAssignmentStatus);
router.patch('/notifications/:notificationId/read', authenticateToken, EnhancedAPIService.markNotificationAsRead);
router.get('/profile', authenticateToken, EnhancedAPIService.getUserProfile);

module.exports = router;