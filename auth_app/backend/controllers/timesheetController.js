const TimeEntry = require('../models/TimeEntry');
const Task = require('../models/Task');

// Get all time entries for the authenticated user
const getTimeEntries = async (req, res) => {
  try {
    const userId = req.user.id;
    const { 
      taskId, 
      startDate, 
      endDate, 
      category, 
      isRunning,
      limit, 
      offset 
    } = req.query;

    const options = {
      taskId,
      startDate: startDate ? new Date(startDate) : null,
      endDate: endDate ? new Date(endDate) : null,
      category,
      isRunning: isRunning !== undefined ? isRunning === 'true' : undefined,
      limit: limit ? parseInt(limit) : undefined,
      offset: offset ? parseInt(offset) : undefined
    };

    const timeEntries = await TimeEntry.findByUserId(userId, options);

    res.json({
      success: true,
      data: timeEntries,
      count: timeEntries.length
    });
  } catch (error) {
    console.error('Get time entries error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to retrieve time entries' 
    });
  }
};

// Get a specific time entry
const getTimeEntry = async (req, res) => {
  try {
    const userId = req.user.id;
    const { entryId } = req.params;

    const timeEntry = await TimeEntry.findById(entryId, userId);
    if (!timeEntry) {
      return res.status(404).json({ 
        success: false, 
        message: 'Time entry not found' 
      });
    }

    res.json({
      success: true,
      data: timeEntry
    });
  } catch (error) {
    console.error('Get time entry error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to retrieve time entry' 
    });
  }
};

// Create a new time entry (manual entry)
const createTimeEntry = async (req, res) => {
  try {
    const userId = req.user.id;
    const { 
      taskId, 
      startTime, 
      endTime, 
      description, 
      category 
    } = req.body;

    if (!taskId || !startTime) {
      return res.status(400).json({ 
        success: false, 
        message: 'Task ID and start time are required' 
      });
    }

    // Validate task exists and belongs to user
    const task = await Task.findById(taskId, userId);
    if (!task) {
      return res.status(404).json({ 
        success: false, 
        message: 'Task not found' 
      });
    }

    // Create time entry
    const timeEntry = await TimeEntry.create({
      userId,
      taskId,
      taskTitle: task.title,
      startTime: new Date(startTime),
      description: description || `Working on ${task.title}`,
      category: category || task.category
    });

    // If endTime is provided, update the entry to complete it
    if (endTime) {
      const updatedEntry = await TimeEntry.update(timeEntry.id, userId, {
        end_time: new Date(endTime),
        is_running: false
      });
      
      return res.status(201).json({
        success: true,
        data: updatedEntry,
        message: 'Time entry created successfully'
      });
    }

    res.status(201).json({
      success: true,
      data: timeEntry,
      message: 'Time entry created successfully'
    });
  } catch (error) {
    console.error('Create time entry error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to create time entry' 
    });
  }
};

// Update a time entry
const updateTimeEntry = async (req, res) => {
  try {
    const userId = req.user.id;
    const { entryId } = req.params;
    const updates = req.body;

    // Validate time entry exists
    const existingEntry = await TimeEntry.findById(entryId, userId);
    if (!existingEntry) {
      return res.status(404).json({ 
        success: false, 
        message: 'Time entry not found' 
      });
    }

    // Process date updates
    if (updates.end_time) {
      updates.end_time = new Date(updates.end_time);
      updates.is_running = false;
    }

    const updatedEntry = await TimeEntry.update(entryId, userId, updates);

    res.json({
      success: true,
      data: updatedEntry,
      message: 'Time entry updated successfully'
    });
  } catch (error) {
    console.error('Update time entry error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to update time entry' 
    });
  }
};

// Delete a time entry
const deleteTimeEntry = async (req, res) => {
  try {
    const userId = req.user.id;
    const { entryId } = req.params;

    const deletedEntry = await TimeEntry.delete(entryId, userId);
    if (!deletedEntry) {
      return res.status(404).json({ 
        success: false, 
        message: 'Time entry not found' 
      });
    }

    res.json({
      success: true,
      data: deletedEntry,
      message: 'Time entry deleted successfully'
    });
  } catch (error) {
    console.error('Delete time entry error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to delete time entry' 
    });
  }
};

// Start timer for a specific task
const startTimer = async (req, res) => {
  try {
    const userId = req.user.id;
    const { taskId, description, category } = req.body;

    if (!taskId) {
      return res.status(400).json({ 
        success: false, 
        message: 'Task ID is required' 
      });
    }

    // Validate task exists
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
      category || task.category, 
      description || `Working on ${task.title}`
    );

    res.json({
      success: true,
      data: result,
      message: 'Timer started successfully'
    });
  } catch (error) {
    console.error('Start timer error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to start timer' 
    });
  }
};

// Stop active timer
const stopTimer = async (req, res) => {
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
    console.error('Stop timer error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to stop timer' 
    });
  }
};

// Pause active timer
const pauseTimer = async (req, res) => {
  try {
    const userId = req.user.id;
    const timeEntry = await TimeEntry.pauseTimer(userId);
    if (!timeEntry) {
      return res.status(404).json({
        success: false,
        message: 'No active timer found to pause'
      });
    }
    res.json({
      success: true,
      data: timeEntry,
      message: 'Timer paused successfully'
    });
  } catch (error) {
    console.error('Pause timer error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to pause timer'
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

// Get today's time statistics
const getTodayStats = async (req, res) => {
  try {
    const userId = req.user.id;

    const stats = await TimeEntry.getTodayStats(userId);

    res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    console.error('Get today stats error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to retrieve today\'s statistics' 
    });
  }
};

// Get weekly time statistics
const getWeeklyStats = async (req, res) => {
  try {
    const userId = req.user.id;

    const stats = await TimeEntry.getWeeklyStats(userId);

    res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    console.error('Get weekly stats error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to retrieve weekly statistics' 
    });
  }
};

// Get monthly time statistics
const getMonthlyStats = async (req, res) => {
  try {
    const userId = req.user.id;
    const { month, year } = req.query;

    const stats = await TimeEntry.getMonthlyStats(
      userId, 
      month ? parseInt(month) : null, 
      year ? parseInt(year) : null
    );

    res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    console.error('Get monthly stats error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to retrieve monthly statistics' 
    });
  }
};

// Get time breakdown by category
const getTimeByCategory = async (req, res) => {
  try {
    const userId = req.user.id;
    const { startDate, endDate } = req.query;

    const start = startDate ? new Date(startDate) : null;
    const end = endDate ? new Date(endDate) : null;

    const stats = await TimeEntry.getTimeByCategory(userId, start, end);

    res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    console.error('Get time by category error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to retrieve time by category' 
    });
  }
};

// Get time breakdown by task
const getTimeByTask = async (req, res) => {
  try {
    const userId = req.user.id;
    const { startDate, endDate } = req.query;

    const start = startDate ? new Date(startDate) : null;
    const end = endDate ? new Date(endDate) : null;

    const stats = await TimeEntry.getTimeByTask(userId, start, end);

    res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    console.error('Get time by task error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to retrieve time by task' 
    });
  }
};

// Get daily timesheet
const getDailyTimesheet = async (req, res) => {
  try {
    const userId = req.user.id;
    const { date } = req.params;

    if (!date) {
      return res.status(400).json({ 
        success: false, 
        message: 'Date parameter is required' 
      });
    }

    const entries = await TimeEntry.getDailyTimesheet(userId, new Date(date));

    // Calculate totals
    const totalMinutes = entries.reduce((sum, entry) => sum + (entry.duration_minutes || 0), 0);
    const sessionCount = entries.length;

    res.json({
      success: true,
      data: {
        date: date,
        entries: entries,
        summary: {
          sessionCount,
          totalMinutes,
          totalHours: Math.floor(totalMinutes / 60),
          remainingMinutes: totalMinutes % 60
        }
      }
    });
  } catch (error) {
    console.error('Get daily timesheet error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to retrieve daily timesheet' 
    });
  }
};

// Get recent time entries
const getRecentEntries = async (req, res) => {
  try {
    const userId = req.user.id;
    const { limit } = req.query;

    const entries = await TimeEntry.getRecentEntries(userId, limit ? parseInt(limit) : 10);

    res.json({
      success: true,
      data: entries
    });
  } catch (error) {
    console.error('Get recent entries error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to retrieve recent entries' 
    });
  }
};

// Generate comprehensive timesheet report
const getTimesheetReport = async (req, res) => {
  try {
    const userId = req.user.id;
    const { startDate, endDate, format = 'json' } = req.query;

    if (!startDate || !endDate) {
      return res.status(400).json({ 
        success: false, 
        message: 'Start date and end date are required' 
      });
    }

    const start = new Date(startDate);
    const end = new Date(endDate);

    const [
      entries,
      categoryBreakdown,
      taskBreakdown,
      dailyStats
    ] = await Promise.all([
      TimeEntry.findByUserId(userId, { startDate: start, endDate: end }),
      TimeEntry.getTimeByCategory(userId, start, end),
      TimeEntry.getTimeByTask(userId, start, end),
      TimeEntry.getWeeklyStats(userId)
    ]);

    const totalMinutes = entries.reduce((sum, entry) => sum + (entry.duration_minutes || 0), 0);
    const totalSessions = entries.length;

    const report = {
      period: {
        startDate: startDate,
        endDate: endDate,
        totalDays: Math.ceil((end - start) / (1000 * 60 * 60 * 24)) + 1
      },
      summary: {
        totalMinutes,
        totalHours: Math.floor(totalMinutes / 60),
        remainingMinutes: totalMinutes % 60,
        totalSessions,
        averageSessionMinutes: totalSessions > 0 ? Math.round(totalMinutes / totalSessions) : 0
      },
      breakdowns: {
        byCategory: categoryBreakdown,
        byTask: taskBreakdown,
        byDay: dailyStats
      },
      entries: entries
    };

    if (format === 'csv') {
      // Generate CSV format
      const csvHeaders = 'Date,Task,Category,Start Time,End Time,Duration (minutes),Description\n';
      const csvRows = entries.map(entry => {
        const startTime = new Date(entry.start_time);
        const endTime = entry.end_time ? new Date(entry.end_time) : null;
        return [
          startTime.toDateString(),
          `"${entry.task_title}"`,
          entry.category,
          startTime.toTimeString().split(' ')[0],
          endTime ? endTime.toTimeString().split(' ')[0] : 'Running',
          entry.duration_minutes || 0,
          `"${entry.description || ''}"`
        ].join(',');
      }).join('\n');

      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', `attachment; filename="timesheet_${startDate}_${endDate}.csv"`);
      res.send(csvHeaders + csvRows);
    } else {
      res.json({
        success: true,
        data: report
      });
    }
  } catch (error) {
    console.error('Get timesheet report error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to generate timesheet report' 
    });
  }
};

module.exports = {
  getTimeEntries,
  getTimeEntry,
  createTimeEntry,
  updateTimeEntry,
  deleteTimeEntry,
  startTimer,
  stopTimer,
  pauseTimer,
  getActiveTimer,
  getTodayStats,
  getWeeklyStats,
  getMonthlyStats,
  getTimeByCategory,
  getTimeByTask,
  getDailyTimesheet,
  getRecentEntries,
  getTimesheetReport
};