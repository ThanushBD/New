const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const { 
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
} = require('../controllers/taskContollers');

// Validation middleware for task creation
const validateTaskCreation = (req, res, next) => {
  const { title, priority, status } = req.body;
  const errors = [];

  if (!title || title.trim().length === 0) {
    errors.push('Task title is required');
  }

  if (title && title.length > 255) {
    errors.push('Task title must be less than 255 characters');
  }

  if (priority && !['low', 'medium', 'high', 'urgent'].includes(priority)) {
    errors.push('Priority must be one of: low, medium, high, urgent');
  }

  if (status && !['pending', 'in_progress', 'completed', 'cancelled'].includes(status)) {
    errors.push('Status must be one of: pending, in_progress, completed, cancelled');
  }

  if (errors.length > 0) {
    return res.status(400).json({ 
      success: false, 
      message: 'Validation failed', 
      errors 
    });
  }

  next();
};

// Validation middleware for task updates
const validateTaskUpdate = (req, res, next) => {
  const { title, priority, status } = req.body;
  const errors = [];

  if (title !== undefined) {
    if (typeof title !== 'string' || title.trim().length === 0) {
      errors.push('Task title must be a non-empty string');
    }
    if (title.length > 255) {
      errors.push('Task title must be less than 255 characters');
    }
  }

  if (priority && !['low', 'medium', 'high', 'urgent'].includes(priority)) {
    errors.push('Priority must be one of: low, medium, high, urgent');
  }

  if (status && !['pending', 'in_progress', 'completed', 'cancelled'].includes(status)) {
    errors.push('Status must be one of: pending, in_progress, completed, cancelled');
  }

  if (errors.length > 0) {
    return res.status(400).json({ 
      success: false, 
      message: 'Validation failed', 
      errors 
    });
  }

  next();
};

// All routes require authentication
router.use(authenticateToken);

// Task CRUD routes
router.get('/', getTasks);                          // GET /api/tasks
router.get('/recent', getRecentTasks);              // GET /api/tasks/recent
router.get('/upcoming', getUpcomingTasks);          // GET /api/tasks/upcoming
router.get('/statistics', getTaskStatistics);      // GET /api/tasks/statistics
router.get('/:taskId', getTask);                    // GET /api/tasks/:taskId

router.post('/', validateTaskCreation, createTask); // POST /api/tasks
router.put('/:taskId', validateTaskUpdate, updateTask); // PUT /api/tasks/:taskId
router.patch('/:taskId/toggle-status', toggleTaskStatus); // PATCH /api/tasks/:taskId/toggle-status
router.delete('/:taskId', deleteTask);              // DELETE /api/tasks/:taskId

// Timer routes for tasks
router.post('/:taskId/start-timer', startTaskTimer); // POST /api/tasks/:taskId/start-timer
router.post('/stop-timer', stopTaskTimer);          // POST /api/tasks/stop-timer
router.get('/timer/active', getActiveTimer);        // GET /api/tasks/timer/active

module.exports = router;