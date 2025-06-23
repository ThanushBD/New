const Task = require('../models/Task');
const TimeEntry = require('../models/TimeEntry');

// Get all tasks for the authenticated user
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
      search 
    } = req.query;

    let tasks;
    if (search) {
      tasks = await Task.searchTasks(userId, search, { 
        status, 
        limit: limit ? parseInt(limit) : undefined 
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
        offset: offset ? parseInt(offset) : undefined
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

// Create a new task
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
      dueDate 
    } = req.body;

    if (!title || title.trim().length === 0) {
      return res.status(400).json({ 
        success: false, 
        message: 'Task title is required' 
      });
    }

    const taskData = {
      userId,
      title: title.trim(),
      description: description || '',
      priority: priority || 'medium',
      category: category || 'General',
      tags: tags || [],
      estimatedMinutes: estimatedMinutes || 60,
      dueDate: dueDate ? new Date(dueDate) : null
    };

    const task = await Task.create(taskData);

    res.status(201).json({
      success: true,
      data: task,
      message: 'Task created successfully'
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

    // Validate task exists
    const existingTask = await Task.findById(taskId, userId);
    if (!existingTask) {
      return res.status(404).json({ 
        success: false, 
        message: 'Task not found' 
      });
    }

    // Process updates
    if (updates.dueDate) {
      updates.dueDate = new Date(updates.dueDate);
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

// Get task statistics
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
      todayTimeStats
    ] = await Promise.all([
      Task.getStatistics(userId, start, end),
      Task.getTasksByCategory(userId),
      Task.getTasksByPriority(userId),
      TimeEntry.getTodayStats(userId)
    ]);

    res.json({
      success: true,
      data: {
        general: generalStats,
        byCategory: categoryStats,
        byPriority: priorityStats,
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
  getActiveTimer
};