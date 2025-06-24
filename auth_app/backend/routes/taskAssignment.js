const express = require('express');
const { body } = require('express-validator');
const auth = require('../middleware/auth');
const TaskAssignmentController = require('../controllers/taskAssignmentController');

const router = express.Router();

// Validation middleware for task assignment
const validateTaskAssignment = [
  body('title')
    .trim()
    .isLength({ min: 1, max: 255 })
    .withMessage('Title must be between 1 and 255 characters'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 1000 })
    .withMessage('Description must not exceed 1000 characters'),
  body('assigned_to')
    .isInt({ min: 1 })
    .withMessage('Assigned to must be a valid user ID'),
  body('priority')
    .optional()
    .isIn(['low', 'medium', 'high', 'urgent'])
    .withMessage('Priority must be low, medium, high, or urgent'),
  body('category')
    .optional()
    .trim()
    .isLength({ max: 100 })
    .withMessage('Category must not exceed 100 characters'),
  body('estimated_hours')
    .optional()
    .isFloat({ min: 0.1, max: 1000 })
    .withMessage('Estimated hours must be between 0.1 and 1000'),
  body('start_date')
    .optional()
    .isISO8601()
    .withMessage('Start date must be a valid ISO 8601 date'),
  body('due_date')
    .optional()
    .isISO8601()
    .withMessage('Due date must be a valid ISO 8601 date'),
  body('tags')
    .optional()
    .isArray()
    .withMessage('Tags must be an array'),
];

// Routes

// Get available users for assignment
router.get('/users/available', auth, TaskAssignmentController.getAvailableUsers);

// Create task with assignment
router.post('/tasks/assign', auth, validateTaskAssignment, TaskAssignmentController.createTaskWithAssignment);

// Get enhanced task statistics
router.get('/tasks/statistics/enhanced', auth, TaskAssignmentController.getEnhancedTaskStatistics);

// Get notifications
router.get('/notifications', auth, TaskAssignmentController.getNotifications);

// Mark notification as read
router.patch('/notifications/:notificationId/read', auth, TaskAssignmentController.markNotificationAsRead);

module.exports = router;