const Task = require('../models/Task');
const TimeEntry = require('../models/TimeEntry');
const pool = require('../config/database');

// Get all tasks for the authenticated user (including assigned tasks)
const getTasks = async (req, res) => {
  try {
    const userId = req.user.id;
    const { 
      status, 
      priority, 
      category, 
      overdue, 
      sortBy, 
      sortOrder, 
      limit, 
      offset,
      search,
      includeAssigned = 'true' // Include tasks assigned to user
    } = req.query;

    let tasks;
    if (search) {
      tasks = await Task.searchTasks(userId, search, { 
        status, 
        limit: limit ? parseInt(limit) : undefined,
        includeAssigned: includeAssigned === 'true'
      });
    } else {
      const options = {
        status,
        priority,
        category,
        overdue: overdue === 'true',
        sortBy,
        sortOrder,
        limit: limit ? parseInt(limit) : undefined,
        offset: offset ? parseInt(offset) : undefined,
        includeAssigned: includeAssigned === 'true'
      };
      tasks = await Task.findByUserId(userId, options);
    }

    res.json({
      success: true,
      data: tasks,
      count: tasks.length
    });
  } catch (error) {
    console.error('Get tasks error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to retrieve tasks' 
    });
  }
};

// Get a specific task
const getTask = async (req, res) => {
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

    res.json({
      success: true,
      data: task
    });
  } catch (error) {
    console.error('Get task error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to retrieve task' 
    });
  }
};

// Enhanced create task with optional assignment
const createTask = async (req, res) => {
  try {
    const userId = req.user.id;
    const { 
      title, 
      description, 
      priority, 
      category, 
      tags, 
      estimatedMinutes,
      estimatedHours,
      dueDate,
      startDate,
      assignedTo, // Optional assignment
      assigned_to // Alternative naming
    } = req.body;

    if (!title || title.trim().length === 0) {
      return res.status(400).json({ 
        success: false, 
        message: 'Task title is required' 
      });
    }

    // Determine if this is an assignment
    const assigneeId = assignedTo || assigned_to;
    const isAssignment = assigneeId && assigneeId !== userId;

    let task;
    
    if (isAssignment) {
      // Use assignment creation logic
      task = await Task.createWithAssignment({
        userId,
        title: title.trim(),
        description: description || '',
        priority: priority || 'medium',
        category: category || 'General',
        tags: tags || [],
        estimatedMinutes: estimatedMinutes || (estimatedHours ? estimatedHours * 60 : 60),
        estimatedHours: estimatedHours || (estimatedMinutes ? estimatedMinutes / 60 : 1),
        dueDate: dueDate ? new Date(dueDate) : null,
        startDate: startDate ? new Date(startDate) : null,
        assignedTo: assigneeId,
        assignedBy: userId
      });
    } else {
      // Regular task creation
      const taskData = {
        userId,
        title: title.trim(),
        description: description || '',
        priority: priority || 'medium',
        category: category || 'General',
        tags: tags || [],
        estimatedMinutes: estimatedMinutes || (estimatedHours ? estimatedHours * 60 : 60),
        dueDate: dueDate ? new Date(dueDate) : null,
        startDate: startDate ? new Date(startDate) : null
      };

      task = await Task.create(taskData);
    }

    res.status(201).json({
      success: true,
      data: task,
      message: isAssignment ? 'Task created and assigned successfully' : 'Task created successfully'
    });
  } catch (error) {
    console.error('Create task error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to create task' 
    });
  }
};

// Update a task
const updateTask = async (req, res) => {
  try {
    const userId = req.user.id;
    const { taskId } = req.params;
    const updates = req.body;

    // Validate task exists and user has permission
    const existingTask = await Task.findById(taskId, userId);
    if (!existingTask) {
      return res.status(404).json({ 
        success: false, 
        message: 'Task not found' 
      });
    }

    // Check if user can update this task
    const canUpdate = existingTask.user_id === userId || 
                     existingTask.assigned_to === userId || 
                     existingTask.assigned_by === userId;
    
    if (!canUpdate) {
      return res.status(403).json({ 
        success: false, 
        message: 'Not authorized to update this task' 
      });
    }

    // Process updates
    if (updates.dueDate) {
      updates.dueDate = new Date(updates.dueDate);
    }
    if (updates.startDate) {
      updates.startDate = new Date(updates.startDate);
    }
    if (updates.estimatedHours) {
      updates.estimatedMinutes = updates.estimatedHours * 60;
    }

    if (updates.status === 'completed' && !updates.completed_at) {
      updates.completed_at = new Date();
    } else if (updates.status !== 'completed') {
      updates.completed_at = null;
    }

    const updatedTask = await Task.update(taskId, userId, updates);

    res.json({
      success: true,
      data: updatedTask,
      message: 'Task updated successfully'
    });
  } catch (error) {
    console.error('Update task error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to update task' 
    });
  }
};

// Toggle task status
const toggleTaskStatus = async (req, res) => {
  try {
    const userId = req.user.id;
    const { taskId } = req.params;

    const updatedTask = await Task.toggleStatus(taskId, userId);
    if (!updatedTask) {
      return res.status(404).json({ 
        success: false, 
        message: 'Task not found' 
      });
    }

    res.json({
      success: true,
      data: updatedTask,
      message: 'Task status updated successfully'
    });
  } catch (error) {
    console.error('Toggle task status error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to update task status' 
    });
  }
};

// Delete a task
const deleteTask = async (req, res) => {
  try {
    const userId = req.user.id;
    const { taskId } = req.params;

    const deletedTask = await Task.delete(taskId, userId);
    if (!deletedTask) {
      return res.status(404).json({ 
        success: false, 
        message: 'Task not found' 
      });
    }

    res.json({
      success: true,
      data: deletedTask,
      message: 'Task deleted successfully'
    });
  } catch (error) {
    console.error('Delete task error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to delete task' 
    });
  }
};

// Get task statistics (enhanced with assignment info)
const getTaskStatistics = async (req, res) => {
  try {
    const userId = req.user.id;
    const { startDate, endDate } = req.query;

    const start = startDate ? new Date(startDate) : null;
    const end = endDate ? new Date(endDate) : null;

    const [
      generalStats,
      categoryStats,
      priorityStats,
      assignmentStats,
      todayTimeStats
    ] = await Promise.all([
      Task.getStatistics(userId, start, end),
      Task.getTasksByCategory(userId),
      Task.getTasksByPriority(userId),
      Task.getAssignmentStatistics(userId),
      TimeEntry.getTodayStats(userId)
    ]);

    res.json({
      success: true,
      data: {
        general: generalStats,
        byCategory: categoryStats,
        byPriority: priorityStats,
        assignments: assignmentStats,
        timeToday: todayTimeStats
      }
    });
  } catch (error) {
    console.error('Get task statistics error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to retrieve task statistics' 
    });
  }
};

// Get recent tasks
const getRecentTasks = async (req, res) => {
  try {
    const userId = req.user.id;
    const { limit } = req.query;

    const tasks = await Task.getRecentTasks(userId, limit ? parseInt(limit) : 5);

    res.json({
      success: true,
      data: tasks
    });
  } catch (error) {
    console.error('Get recent tasks error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to retrieve recent tasks' 
    });
  }
};

// Get upcoming tasks
const getUpcomingTasks = async (req, res) => {
  try {
    const userId = req.user.id;
    const { days } = req.query;

    const tasks = await Task.getUpcomingTasks(userId, days ? parseInt(days) : 7);

    res.json({
      success: true,
      data: tasks
    });
  } catch (error) {
    console.error('Get upcoming tasks error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to retrieve upcoming tasks' 
    });
  }
};

// Start timer for a task
const startTaskTimer = async (req, res) => {
  try {
    const userId = req.user.id;
    const { taskId } = req.params;
    const { description } = req.body;

    // Get task details
    const task = await Task.findById(taskId, userId);
    if (!task) {
      return res.status(404).json({ 
        success: false, 
        message: 'Task not found' 
      });
    }

    const result = await TimeEntry.startTimer(
      userId, 
      taskId, 
      task.title, 
      task.category, 
      description || `Working on ${task.title}`
    );

    res.json({
      success: true,
      data: result,
      message: 'Timer started successfully'
    });
  } catch (error) {
    console.error('Start task timer error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to start timer' 
    });
  }
};

// Stop timer
const stopTaskTimer = async (req, res) => {
  try {
    const userId = req.user.id;

    const timeEntry = await TimeEntry.stopTimer(userId);
    if (!timeEntry) {
      return res.status(404).json({ 
        success: false, 
        message: 'No active timer found' 
      });
    }

    res.json({
      success: true,
      data: timeEntry,
      message: 'Timer stopped successfully'
    });
  } catch (error) {
    console.error('Stop task timer error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to stop timer' 
    });
  }
};

// Get active timer
const getActiveTimer = async (req, res) => {
  try {
    const userId = req.user.id;

    const activeTimer = await TimeEntry.getActiveTimer(userId);

    res.json({
      success: true,
      data: activeTimer
    });
  } catch (error) {
    console.error('Get active timer error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to retrieve active timer' 
    });
  }
};

// Get available users for assignment
const getAvailableUsers = async (req, res) => {
  try {
    const userId = req.user.id;
    
    const result = await pool.query(
      'SELECT * FROM get_available_users($1)',
      [userId]
    );
    
    res.json({
      success: true,
      data: result.rows,
      users: result.rows // Alternative property name for compatibility
    });
  } catch (error) {
    console.error('Error getting available users:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get available users',
      error: error.message,
    });
  }
};

module.exports = {
  getTasks,
  getTask,
  createTask,
  updateTask,
  toggleTaskStatus,
  deleteTask,
  getTaskStatistics,
  getRecentTasks,
  getUpcomingTasks,
  startTaskTimer,
  stopTaskTimer,
  getActiveTimer,
  getAvailableUsers
};