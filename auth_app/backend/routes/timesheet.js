const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const {
  getTimeEntries,
  getTimeEntry,
  createTimeEntry,
  updateTimeEntry,
  deleteTimeEntry,
  startTimer,
  stopTimer,
  getActiveTimer,
  getTodayStats,
  getWeeklyStats,
  getMonthlyStats,
  getTimeByCategory,
  getTimeByTask,
  getDailyTimesheet,
  getRecentEntries,
  getTimesheetReport
} = require('../controllers/timesheetController');

// Validation middleware for time entry creation
const validateTimeEntryCreation = (req, res, next) => {
  const { taskId, startTime } = req.body;
  const errors = [];

  if (!taskId) {
    errors.push('Task ID is required');
  }

  if (!startTime) {
    errors.push('Start time is required');
  } else {
    const startDate = new Date(startTime);
    if (isNaN(startDate.getTime())) {
      errors.push('Start time must be a valid date');
    }
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

// Validation middleware for timer start
const validateTimerStart = (req, res, next) => {
  const { taskId } = req.body;
  const errors = [];

  if (!taskId) {
    errors.push('Task ID is required');
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

// Date validation middleware
const validateDateParam = (req, res, next) => {
  const { date } = req.params;
  
  if (date) {
    const parsedDate = new Date(date);
    if (isNaN(parsedDate.getTime())) {
      return res.status(400).json({ 
        success: false, 
        message: 'Invalid date format' 
      });
    }
  }

  next();
};

// Query parameter validation for reports
const validateReportQuery = (req, res, next) => {
  const { startDate, endDate } = req.query;
  const errors = [];

  if (startDate && endDate) {
    const start = new Date(startDate);
    const end = new Date(endDate);

    if (isNaN(start.getTime())) {
      errors.push('Start date must be a valid date');
    }

    if (isNaN(end.getTime())) {
      errors.push('End date must be a valid date');
    }

    if (!isNaN(start.getTime()) && !isNaN(end.getTime()) && start > end) {
      errors.push('Start date must be before end date');
    }
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

// Time entry CRUD routes
router.get('/', getTimeEntries);                    // GET /api/timesheet
router.get('/recent', getRecentEntries);            // GET /api/timesheet/recent
router.get('/:entryId', getTimeEntry);              // GET /api/timesheet/:entryId

router.post('/', validateTimeEntryCreation, createTimeEntry); // POST /api/timesheet
router.put('/:entryId', updateTimeEntry);           // PUT /api/timesheet/:entryId
router.delete('/:entryId', deleteTimeEntry);        // DELETE /api/timesheet/:entryId

// Timer management routes
router.post('/timer/start', validateTimerStart, startTimer); // POST /api/timesheet/timer/start
router.post('/timer/stop', stopTimer);              // POST /api/timesheet/timer/stop
router.get('/timer/active', getActiveTimer);        // GET /api/timesheet/timer/active

// Statistics and analytics routes
router.get('/stats/today', getTodayStats);          // GET /api/timesheet/stats/today
router.get('/stats/weekly', getWeeklyStats);        // GET /api/timesheet/stats/weekly
router.get('/stats/monthly', getMonthlyStats);      // GET /api/timesheet/stats/monthly

// Time breakdown routes
router.get('/breakdown/category', validateReportQuery, getTimeByCategory); // GET /api/timesheet/breakdown/category
router.get('/breakdown/task', validateReportQuery, getTimeByTask);         // GET /api/timesheet/breakdown/task

// Daily timesheet routes
router.get('/daily/:date', validateDateParam, getDailyTimesheet); // GET /api/timesheet/daily/:date

// Report generation routes
router.get('/reports/timesheet', validateReportQuery, getTimesheetReport); // GET /api/timesheet/reports/timesheet

module.exports = router;