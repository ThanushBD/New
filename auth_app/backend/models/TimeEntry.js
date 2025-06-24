const pool = require('../config/database');
const { Pool } = require('pg');

function nowISO() {
  return new Date().toISOString();
}

function calcTotalDuration(intervals) {
  let total = 0;
  for (const interval of intervals) {
    if (interval.start && interval.stop) {
      total += (new Date(interval.stop) - new Date(interval.start)) / 1000;
    }
  }
  return Math.floor(total);
}

class TimeEntry {
  static async create({ userId, taskId, taskTitle, startTime, description = '', category = 'General' }) {
    const query = `
      INSERT INTO time_entries (user_id, task_id, task_title, start_time, description, category, is_running)
      VALUES ($1, $2, $3, $4, $5, $6, true)
      RETURNING *
    `;
    const values = [userId, taskId, taskTitle, startTime, description, category];
    const result = await pool.query(query, values);
    return result.rows[0];
  }

  static async findByUserId(userId, options = {}) {
    let query = `
      SELECT te.*, t.title as task_title, t.category
      FROM time_entries te
      LEFT JOIN tasks t ON te.task_id = t.id
      WHERE te.user_id = $1
    `;

    const values = [userId];
    let paramCount = 1;

    // Add filters
    if (options.taskId) {
      paramCount++;
      query += ` AND te.task_id = $${paramCount}`;
      values.push(options.taskId);
    }

    if (options.startDate && options.endDate) {
      paramCount++;
      query += ` AND te.start_time >= $${paramCount}`;
      values.push(options.startDate);
      paramCount++;
      query += ` AND te.start_time <= $${paramCount}`;
      values.push(options.endDate);
    }

    if (options.isRunning !== undefined) {
      paramCount++;
      query += ` AND te.is_running = $${paramCount}`;
      values.push(options.isRunning);
    }

    if (options.category) {
      paramCount++;
      query += ` AND te.category = $${paramCount}`;
      values.push(options.category);
    }

    // Add sorting
    query += ` ORDER BY te.start_time DESC`;

    // Add pagination
    if (options.limit) {
      paramCount++;
      query += ` LIMIT $${paramCount}`;
      values.push(options.limit);
    }

    if (options.offset) {
      paramCount++;
      query += ` OFFSET $${paramCount}`;
      values.push(options.offset);
    }

    const result = await pool.query(query, values);
    return result.rows;
  }

  static async findById(entryId, userId) {
    const query = `
      SELECT te.*, t.title as task_title, t.category
      FROM time_entries te
      LEFT JOIN tasks t ON te.task_id = t.id
      WHERE te.id = $1 AND te.user_id = $2
    `;
    const result = await pool.query(query, [entryId, userId]);
    return result.rows[0];
  }

  static async update(entryId, userId, updates) {
    const allowedFields = ['end_time', 'description', 'is_running'];
    const updateFields = [];
    const values = [];
    let paramCount = 0;

    for (const [key, value] of Object.entries(updates)) {
      if (allowedFields.includes(key)) {
        paramCount++;
        updateFields.push(`${key} = $${paramCount}`);
        values.push(value);
      }
    }

    if (updateFields.length === 0) {
      throw new Error('No valid fields to update');
    }

    // Add updated_at
    paramCount++;
    updateFields.push(`updated_at = $${paramCount}`);
    values.push(new Date());

    // Add WHERE conditions
    paramCount++;
    values.push(entryId);
    paramCount++;
    values.push(userId);

    const query = `
      UPDATE time_entries 
      SET ${updateFields.join(', ')}
      WHERE id = $${paramCount - 1} AND user_id = $${paramCount}
      RETURNING *
    `;

    const result = await pool.query(query, values);
    return result.rows[0];
  }

  static async delete(entryId, userId) {
    const query = 'DELETE FROM time_entries WHERE id = $1 AND user_id = $2 RETURNING *';
    const result = await pool.query(query, [entryId, userId]);
    return result.rows[0];
  }

  // Active Timer Management
  static async startTimer(userId, taskId, taskTitle, category = 'General', description = '') {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      // Stop any existing active timer
      await this.stopActiveTimer(userId, client);
      // Check for a paused entry (end_time is null, is_running is false)
      const pausedQuery = `SELECT * FROM time_entries WHERE user_id = $1 AND task_id = $2 AND end_time IS NULL AND is_running = false ORDER BY start_time DESC LIMIT 1`;
      const pausedResult = await client.query(pausedQuery, [userId, taskId]);
      let entry;
      if (pausedResult.rows.length > 0) {
        // Resume: append new interval
        entry = pausedResult.rows[0];
        let intervals = entry.intervals || [];
        if (typeof intervals === 'string') intervals = JSON.parse(intervals);
        intervals.push({ start: nowISO() });
        const updateQuery = `UPDATE time_entries SET is_running = true, intervals = $1 WHERE id = $2 RETURNING *`;
        const updateResult = await client.query(updateQuery, [JSON.stringify(intervals), entry.id]);
        entry = updateResult.rows[0];
      } else {
        // New entry
        const intervals = [{ start: nowISO() }];
        const insertQuery = `INSERT INTO time_entries (user_id, task_id, task_title, start_time, description, category, is_running, intervals, total_duration) VALUES ($1, $2, $3, $4, $5, $6, true, $7, 0) RETURNING *`;
        const startTime = new Date();
        const insertResult = await client.query(insertQuery, [userId, taskId, taskTitle, startTime, description, category, JSON.stringify(intervals)]);
        entry = insertResult.rows[0];
      }
      // Create/Update active timer
      const activeTimerQuery = `INSERT INTO active_timers (user_id, task_id, task_title, start_time, description, category) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`;
      const activeResult = await client.query(activeTimerQuery, [userId, taskId, taskTitle, new Date(), description, category]);
      await client.query('COMMIT');
      return { activeTimer: activeResult.rows[0], timeEntry: entry };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  static async pauseTimer(userId) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      // Get active timer
      const activeTimerQuery = 'SELECT * FROM active_timers WHERE user_id = $1';
      const activeResult = await client.query(activeTimerQuery, [userId]);
      if (activeResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return null;
      }
      const activeTimer = activeResult.rows[0];
      // Update time entry: close interval, update total_duration, set is_running false
      const entryQuery = `SELECT * FROM time_entries WHERE user_id = $1 AND task_id = $2 AND is_running = true AND end_time IS NULL ORDER BY start_time DESC LIMIT 1`;
      const entryResult = await client.query(entryQuery, [userId, activeTimer.task_id]);
      if (entryResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return null;
      }
      let entry = entryResult.rows[0];
      let intervals = entry.intervals || [];
      if (typeof intervals === 'string') intervals = JSON.parse(intervals);
      if (intervals.length === 0 || intervals[intervals.length - 1].stop) {
        await client.query('ROLLBACK');
        return null;
      }
      intervals[intervals.length - 1].stop = nowISO();
      const total_duration = calcTotalDuration(intervals);
      const updateQuery = `UPDATE time_entries SET is_running = false, intervals = $1, total_duration = $2 WHERE id = $3 RETURNING *`;
      const updateResult = await client.query(updateQuery, [JSON.stringify(intervals), total_duration, entry.id]);
      entry = updateResult.rows[0];
      // Delete active timer
      const deleteTimerQuery = 'DELETE FROM active_timers WHERE user_id = $1';
      await client.query(deleteTimerQuery, [userId]);
      await client.query('COMMIT');
      return entry;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  static async stopTimer(userId) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      // Get active timer
      const activeTimerQuery = 'SELECT * FROM active_timers WHERE user_id = $1';
      const activeResult = await client.query(activeTimerQuery, [userId]);
      if (activeResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return null;
      }
      const activeTimer = activeResult.rows[0];
      // Update time entry: close interval, update total_duration, set is_running false, set end_time
      const entryQuery = `SELECT * FROM time_entries WHERE user_id = $1 AND task_id = $2 AND is_running = true AND end_time IS NULL ORDER BY start_time DESC LIMIT 1`;
      const entryResult = await client.query(entryQuery, [userId, activeTimer.task_id]);
      if (entryResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return null;
      }
      let entry = entryResult.rows[0];
      let intervals = entry.intervals || [];
      if (typeof intervals === 'string') intervals = JSON.parse(intervals);
      if (intervals.length === 0 || intervals[intervals.length - 1].stop) {
        await client.query('ROLLBACK');
        return null;
      }
      intervals[intervals.length - 1].stop = nowISO();
      const total_duration = calcTotalDuration(intervals);
      const updateQuery = `UPDATE time_entries SET is_running = false, end_time = $1, intervals = $2, total_duration = $3 WHERE id = $4 RETURNING *`;
      const endTime = new Date();
      const updateResult = await client.query(updateQuery, [endTime, JSON.stringify(intervals), total_duration, entry.id]);
      entry = updateResult.rows[0];
      // Delete active timer
      const deleteTimerQuery = 'DELETE FROM active_timers WHERE user_id = $1';
      await client.query(deleteTimerQuery, [userId]);
      await client.query('COMMIT');
      return entry;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  static async getActiveTimer(userId) {
    const query = `
      SELECT at.*, t.title as task_title, t.category
      FROM active_timers at
      LEFT JOIN tasks t ON at.task_id = t.id
      WHERE at.user_id = $1
    `;
    const result = await pool.query(query, [userId]);
    return result.rows[0];
  }

  static async stopActiveTimer(userId, client = null) {
    const queryClient = client || pool;
    
    // Get active timer
    const activeTimerQuery = 'SELECT * FROM active_timers WHERE user_id = $1';
    const activeResult = await queryClient.query(activeTimerQuery, [userId]);
    
    if (activeResult.rows.length > 0) {
      const activeTimer = activeResult.rows[0];
      const endTime = new Date();

      // Update time entry
      const updateEntryQuery = `
        UPDATE time_entries 
        SET end_time = $1, is_running = false
        WHERE user_id = $2 AND task_id = $3 AND is_running = true
      `;
      await queryClient.query(updateEntryQuery, [endTime, userId, activeTimer.task_id]);

      // Delete active timer
      const deleteTimerQuery = 'DELETE FROM active_timers WHERE user_id = $1';
      await queryClient.query(deleteTimerQuery, [userId]);
    }
  }

  // Statistics and Analytics
  static async getTodayStats(userId) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const query = `
      SELECT 
        COUNT(*) as session_count,
        COALESCE(SUM(duration_minutes), 0) as total_minutes,
        COALESCE(AVG(duration_minutes), 0) as avg_minutes,
        MIN(start_time) as first_session,
        MAX(end_time) as last_session
      FROM time_entries
      WHERE user_id = $1 
      AND start_time >= $2 
      AND start_time < $3
      AND end_time IS NOT NULL
    `;
    
    const result = await pool.query(query, [userId, today, tomorrow]);
    return result.rows[0];
  }

  static async getWeeklyStats(userId) {
    const startOfWeek = new Date();
    startOfWeek.setDate(startOfWeek.getDate() - startOfWeek.getDay());
    startOfWeek.setHours(0, 0, 0, 0);

    const query = `
      SELECT 
        DATE(start_time) as date,
        COUNT(*) as session_count,
        COALESCE(SUM(duration_minutes), 0) as total_minutes,
        COALESCE(AVG(duration_minutes), 0) as avg_minutes
      FROM time_entries
      WHERE user_id = $1 
      AND start_time >= $2
      AND end_time IS NOT NULL
      GROUP BY DATE(start_time)
      ORDER BY date
    `;
    
    const result = await pool.query(query, [userId, startOfWeek]);
    return result.rows;
  }

  static async getMonthlyStats(userId, month = null, year = null) {
    const currentDate = new Date();
    const targetMonth = month || currentDate.getMonth() + 1;
    const targetYear = year || currentDate.getFullYear();

    const query = `
      SELECT 
        DATE(start_time) as date,
        COUNT(*) as session_count,
        COALESCE(SUM(duration_minutes), 0) as total_minutes,
        category,
        task_title
      FROM time_entries
      WHERE user_id = $1 
      AND EXTRACT(MONTH FROM start_time) = $2
      AND EXTRACT(YEAR FROM start_time) = $3
      AND end_time IS NOT NULL
      GROUP BY DATE(start_time), category, task_title
      ORDER BY date DESC
    `;
    
    const result = await pool.query(query, [userId, targetMonth, targetYear]);
    return result.rows;
  }

  static async getTimeByCategory(userId, startDate = null, endDate = null) {
    let dateFilter = '';
    const values = [userId];
    let paramCount = 1;

    if (startDate && endDate) {
      paramCount++;
      dateFilter = ` AND start_time >= $${paramCount}`;
      values.push(startDate);
      paramCount++;
      dateFilter += ` AND start_time <= $${paramCount}`;
      values.push(endDate);
    }

    const query = `
      SELECT 
        category,
        COUNT(*) as session_count,
        COALESCE(SUM(duration_minutes), 0) as total_minutes,
        COALESCE(AVG(duration_minutes), 0) as avg_minutes
      FROM time_entries
      WHERE user_id = $1 ${dateFilter}
      AND end_time IS NOT NULL
      GROUP BY category
      ORDER BY total_minutes DESC
    `;
    
    const result = await pool.query(query, values);
    return result.rows;
  }

  static async getTimeByTask(userId, startDate = null, endDate = null) {
    let dateFilter = '';
    const values = [userId];
    let paramCount = 1;

    if (startDate && endDate) {
      paramCount++;
      dateFilter = ` AND te.start_time >= $${paramCount}`;
      values.push(startDate);
      paramCount++;
      dateFilter += ` AND te.start_time <= $${paramCount}`;
      values.push(endDate);
    }

    const query = `
      SELECT 
        te.task_id,
        te.task_title,
        t.category,
        t.status,
        COUNT(*) as session_count,
        COALESCE(SUM(te.duration_minutes), 0) as total_minutes,
        COALESCE(AVG(te.duration_minutes), 0) as avg_minutes,
        MIN(te.start_time) as first_session,
        MAX(te.end_time) as last_session
      FROM time_entries te
      LEFT JOIN tasks t ON te.task_id = t.id
      WHERE te.user_id = $1 ${dateFilter}
      AND te.end_time IS NOT NULL
      GROUP BY te.task_id, te.task_title, t.category, t.status
      ORDER BY total_minutes DESC
    `;
    
    const result = await pool.query(query, values);
    return result.rows;
  }

  static async getDailyTimesheet(userId, date) {
    const startOfDay = new Date(date);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(date);
    endOfDay.setHours(23, 59, 59, 999);

    const query = `
      SELECT te.*, t.category, t.status
      FROM time_entries te
      LEFT JOIN tasks t ON te.task_id = t.id
      WHERE te.user_id = $1 
      AND te.start_time >= $2 
      AND te.start_time <= $3
      AND te.end_time IS NOT NULL
      ORDER BY te.start_time
    `;
    
    const result = await pool.query(query, [userId, startOfDay, endOfDay]);
    return result.rows;
  }

  static async getRecentEntries(userId, limit = 10) {
    const query = `
      SELECT te.*, t.category, t.status
      FROM time_entries te
      LEFT JOIN tasks t ON te.task_id = t.id
      WHERE te.user_id = $1 
      AND te.end_time IS NOT NULL
      ORDER BY te.end_time DESC
      LIMIT $2
    `;
    
    const result = await pool.query(query, [userId, limit]);
    return result.rows;
  }
}

module.exports = TimeEntry;