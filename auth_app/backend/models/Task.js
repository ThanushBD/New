const pool = require('../config/database');

class Task {
  static async create({ userId, title, description, priority = 'medium', category = 'General', tags = [], estimatedMinutes = 60, estimatedHours, dueDate = null, startDate = null, assigned_to = null }) {
    const query = `
      INSERT INTO tasks (user_id, title, description, priority, category, tags, estimated_minutes, estimated_hours, due_date, start_date, assigned_to)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      RETURNING *
    `;
    const estimatedHoursValue = estimatedHours || (estimatedMinutes / 60);
    const values = [userId, title, description, priority, category, tags, estimatedMinutes, estimatedHoursValue, dueDate, startDate, assigned_to];
    const result = await pool.query(query, values);
    return result.rows[0];
  }

  static async createWithAssignment({ userId, title, description, priority = 'medium', category = 'General', tags = [], estimatedMinutes = 60, estimatedHours, dueDate = null, startDate = null, assignedTo, assignedBy }) {
    const client = await pool.connect();
    
    try {
      await client.query('BEGIN');

      // Create the task with assignment
      const taskQuery = `
        INSERT INTO tasks (
          user_id, title, description, priority, category, tags, 
          estimated_minutes, estimated_hours, due_date, start_date, 
          assigned_to, assigned_by
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        RETURNING *
      `;
      const estimatedHoursValue = estimatedHours || (estimatedMinutes / 60);
      const taskValues = [
        userId, title, description, priority, category, tags, 
        estimatedMinutes, estimatedHoursValue, dueDate, startDate, 
        assignedTo, assignedBy
      ];
      const taskResult = await client.query(taskQuery, taskValues);
      const task = taskResult.rows[0];

      // Create assignment record
      const assignmentQuery = `
        INSERT INTO task_assignments (task_id, assigned_by, assigned_to)
        VALUES ($1, $2, $3)
      `;
      await client.query(assignmentQuery, [task.id, assignedBy, assignedTo]);

      // Get assignee info for notification
      const userQuery = 'SELECT first_name, last_name FROM users WHERE id = $1';
      const userResult = await client.query(userQuery, [assignedTo]);
      const assignee = userResult.rows[0];

      // Create notification
      const notificationQuery = `
        INSERT INTO notifications (user_id, task_id, type, title, message)
        VALUES ($1, $2, $3, $4, $5)
      `;
      await client.query(notificationQuery, [
        assignedTo,
        task.id,
        'task_assigned',
        'New Task Assigned',
        `You have been assigned a new task: ${title}`
      ]);

      await client.query('COMMIT');
      return task;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  static async findByUserId(userId, options = {}) {
    let query = `
      SELECT t.*, 
             COALESCE(te.total_time_minutes, 0) as total_logged_time,
             CASE 
               WHEN t.due_date IS NOT NULL AND t.due_date < CURRENT_TIMESTAMP AND t.status != 'completed'
               THEN true 
               ELSE false 
             END as is_overdue,
             COUNT(time_entries.id) as session_count,
             creator.first_name as creator_first_name,
             creator.last_name as creator_last_name,
             creator.email as creator_email,
             assignee.first_name as assignee_first_name,
             assignee.last_name as assignee_last_name,
             assignee.email as assignee_email,
             assignee.avatar_url as assignee_avatar
      FROM tasks t
      LEFT JOIN (
        SELECT task_id, SUM(duration_minutes) as total_time_minutes
        FROM time_entries 
        WHERE end_time IS NOT NULL
        GROUP BY task_id
      ) te ON t.id = te.task_id
      LEFT JOIN time_entries ON t.id = time_entries.task_id
      LEFT JOIN users creator ON t.assigned_by = creator.id
      LEFT JOIN users assignee ON t.assigned_to = assignee.id
      WHERE (t.user_id = $1 OR (t.assigned_to = $1 AND $2 = true))
    `;

    const values = [userId, options.includeAssigned !== false];
    let paramCount = 2;

    // Add filters
    if (options.status) {
      paramCount++;
      query += ` AND t.status = $${paramCount}`;
      values.push(options.status);
    }

    if (options.priority) {
      paramCount++;
      query += ` AND t.priority = $${paramCount}`;
      values.push(options.priority);
    }

    if (options.category) {
      paramCount++;
      query += ` AND t.category = $${paramCount}`;
      values.push(options.category);
    }

    if (options.overdue) {
      query += ` AND t.due_date IS NOT NULL AND t.due_date < CURRENT_TIMESTAMP AND t.status != 'completed'`;
    }

    query += ` GROUP BY t.id, te.total_time_minutes, creator.first_name, creator.last_name, creator.email, assignee.first_name, assignee.last_name, assignee.email, assignee.avatar_url`;

    // Add sorting
    if (options.sortBy) {
      const sortOrder = options.sortOrder || 'ASC';
      query += ` ORDER BY t.${options.sortBy} ${sortOrder}`;
    } else {
      query += ` ORDER BY t.created_at DESC`;
    }

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

  static async findById(taskId, userId) {
    const query = `
      SELECT t.*, 
             COALESCE(te.total_time_minutes, 0) as total_logged_time,
             CASE 
               WHEN t.due_date IS NOT NULL AND t.due_date < CURRENT_TIMESTAMP AND t.status != 'completed'
               THEN true 
               ELSE false 
             END as is_overdue,
             COUNT(time_entries.id) as session_count,
             creator.first_name as creator_first_name,
             creator.last_name as creator_last_name,
             creator.email as creator_email,
             assignee.first_name as assignee_first_name,
             assignee.last_name as assignee_last_name,
             assignee.email as assignee_email,
             assignee.avatar_url as assignee_avatar
      FROM tasks t
      LEFT JOIN (
        SELECT task_id, SUM(duration_minutes) as total_time_minutes
        FROM time_entries 
        WHERE end_time IS NOT NULL
        GROUP BY task_id
      ) te ON t.id = te.task_id
      LEFT JOIN time_entries ON t.id = time_entries.task_id
      LEFT JOIN users creator ON t.assigned_by = creator.id
      LEFT JOIN users assignee ON t.assigned_to = assignee.id
      WHERE t.id = $1 AND (t.user_id = $2 OR t.assigned_to = $2 OR t.assigned_by = $2)
      GROUP BY t.id, te.total_time_minutes, creator.first_name, creator.last_name, creator.email, assignee.first_name, assignee.last_name, assignee.email, assignee.avatar_url
    `;
    const result = await pool.query(query, [taskId, userId]);
    return result.rows[0];
  }

  static async update(taskId, userId, updates) {
    const allowedFields = [
      'title', 'description', 'priority', 'status', 'category', 'tags', 
      'estimated_minutes', 'estimated_hours', 'due_date', 'start_date', 
      'completed_at', 'assigned_to'
    ];
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

    // Add WHERE conditions - allow update if user owns, is assigned to, or assigned by
    paramCount++;
    values.push(taskId);
    paramCount++;
    values.push(userId);

    const query = `
      UPDATE tasks 
      SET ${updateFields.join(', ')}
      WHERE id = $${paramCount - 1} 
      AND (user_id = $${paramCount} OR assigned_to = $${paramCount} OR assigned_by = $${paramCount})
      RETURNING *
    `;

    const result = await pool.query(query, values);
    return result.rows[0];
  }

  static async delete(taskId, userId) {
    const query = `
      DELETE FROM tasks 
      WHERE id = $1 AND (user_id = $2 OR assigned_by = $2)
      RETURNING *
    `;
    const result = await pool.query(query, [taskId, userId]);
    return result.rows[0];
  }

  static async getStatistics(userId, startDate = null, endDate = null) {
    let dateFilter = '';
    const values = [userId];
    let paramCount = 1;

    if (startDate && endDate) {
      paramCount++;
      dateFilter = ` AND t.created_at >= $${paramCount}`;
      values.push(startDate);
      paramCount++;
      dateFilter += ` AND t.created_at <= $${paramCount}`;
      values.push(endDate);
    }

    const query = `
      SELECT 
        COUNT(*) as total_tasks,
        COUNT(*) FILTER (WHERE status = 'completed') as completed_tasks,
        COUNT(*) FILTER (WHERE status = 'in_progress') as in_progress_tasks,
        COUNT(*) FILTER (WHERE status = 'pending') as pending_tasks,
        COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_tasks,
        COUNT(*) FILTER (WHERE due_date IS NOT NULL AND due_date < CURRENT_TIMESTAMP AND status != 'completed') as overdue_tasks,
        AVG(actual_minutes) FILTER (WHERE status = 'completed' AND actual_minutes > 0) as avg_completion_time,
        SUM(actual_minutes) as total_time_spent,
        COUNT(*) FILTER (WHERE priority = 'urgent') as urgent_tasks,
        COUNT(*) FILTER (WHERE priority = 'high') as high_priority_tasks,
        ROUND(
          (COUNT(*) FILTER (WHERE status = 'completed')::DECIMAL / NULLIF(COUNT(*), 0)) * 100, 
          2
        ) as completion_rate
      FROM tasks t
      WHERE (t.user_id = $1 OR t.assigned_to = $1) ${dateFilter}
    `;

    const result = await pool.query(query, values);
    return result.rows[0];
  }

  static async getAssignmentStatistics(userId) {
    const query = `
      SELECT 
        COUNT(*) FILTER (WHERE assigned_to = $1) as assigned_to_me,
        COUNT(*) FILTER (WHERE assigned_by = $1) as assigned_by_me,
        COUNT(*) FILTER (WHERE assigned_to = $1 AND status = 'completed') as completed_assignments,
        COUNT(*) FILTER (WHERE assigned_to = $1 AND status = 'pending') as pending_assignments,
        COUNT(*) FILTER (WHERE assigned_to = $1 AND status = 'in_progress') as in_progress_assignments
      FROM tasks
      WHERE assigned_to = $1 OR assigned_by = $1
    `;
    const result = await pool.query(query, [userId]);
    return result.rows[0];
  }

  static async getTasksByCategory(userId) {
    const query = `
      SELECT 
        category,
        COUNT(*) as total_tasks,
        COUNT(*) FILTER (WHERE status = 'completed') as completed_tasks,
        SUM(actual_minutes) as total_time_minutes
      FROM tasks
      WHERE user_id = $1 OR assigned_to = $1
      GROUP BY category
      ORDER BY total_tasks DESC
    `;
    const result = await pool.query(query, [userId]);
    return result.rows;
  }

  static async getTasksByPriority(userId) {
    const query = `
      SELECT 
        priority,
        COUNT(*) as total_tasks,
        COUNT(*) FILTER (WHERE status = 'completed') as completed_tasks,
        COUNT(*) FILTER (WHERE status = 'pending') as pending_tasks,
        COUNT(*) FILTER (WHERE status = 'in_progress') as in_progress_tasks
      FROM tasks
      WHERE user_id = $1 OR assigned_to = $1
      GROUP BY priority
      ORDER BY 
        CASE priority 
          WHEN 'urgent' THEN 1 
          WHEN 'high' THEN 2 
          WHEN 'medium' THEN 3 
          WHEN 'low' THEN 4 
        END
    `;
    const result = await pool.query(query, [userId]);
    return result.rows;
  }

  static async getRecentTasks(userId, limit = 5) {
    const query = `
      SELECT t.*, 
             COALESCE(te.total_time_minutes, 0) as total_logged_time,
             CASE 
               WHEN t.due_date IS NOT NULL AND t.due_date < CURRENT_TIMESTAMP AND t.status != 'completed'
               THEN true 
               ELSE false 
             END as is_overdue,
             assignee.first_name as assignee_first_name,
             assignee.last_name as assignee_last_name
      FROM tasks t
      LEFT JOIN (
        SELECT task_id, SUM(duration_minutes) as total_time_minutes
        FROM time_entries 
        WHERE end_time IS NOT NULL
        GROUP BY task_id
      ) te ON t.id = te.task_id
      LEFT JOIN users assignee ON t.assigned_to = assignee.id
      WHERE t.user_id = $1 OR t.assigned_to = $1
      ORDER BY t.updated_at DESC
      LIMIT $2
    `;
    const result = await pool.query(query, [userId, limit]);
    return result.rows;
  }

  static async toggleStatus(taskId, userId) {
    // First get the current task
    const currentTask = await this.findById(taskId, userId);
    if (!currentTask) {
      throw new Error('Task not found');
    }

    let newStatus;
    let completedAt = null;

    switch (currentTask.status) {
      case 'pending':
        newStatus = 'in_progress';
        break;
      case 'in_progress':
        newStatus = 'completed';
        completedAt = new Date();
        break;
      case 'completed':
        newStatus = 'pending';
        break;
      case 'cancelled':
        newStatus = 'pending';
        break;
      default:
        newStatus = 'pending';
    }

    return await this.update(taskId, userId, { 
      status: newStatus, 
      completed_at: completedAt 
    });
  }

  static async getUpcomingTasks(userId, days = 7) {
    const query = `
      SELECT t.*, 
             COALESCE(te.total_time_minutes, 0) as total_logged_time,
             CASE 
               WHEN t.due_date IS NOT NULL AND t.due_date < CURRENT_TIMESTAMP
               THEN true 
               ELSE false 
             END as is_overdue,
             assignee.first_name as assignee_first_name,
             assignee.last_name as assignee_last_name
      FROM tasks t
      LEFT JOIN (
        SELECT task_id, SUM(duration_minutes) as total_time_minutes
        FROM time_entries 
        WHERE end_time IS NOT NULL
        GROUP BY task_id
      ) te ON t.id = te.task_id
      LEFT JOIN users assignee ON t.assigned_to = assignee.id
      WHERE (t.user_id = $1 OR t.assigned_to = $1)
      AND t.status != 'completed'
      AND t.due_date IS NOT NULL
      AND t.due_date <= CURRENT_TIMESTAMP + INTERVAL '${days} days'
      ORDER BY t.due_date ASC
    `;
    const result = await pool.query(query, [userId]);
    return result.rows;
  }

  static async searchTasks(userId, searchTerm, options = {}) {
    let query = `
      SELECT t.*, 
             COALESCE(te.total_time_minutes, 0) as total_logged_time,
             CASE 
               WHEN t.due_date IS NOT NULL AND t.due_date < CURRENT_TIMESTAMP AND t.status != 'completed'
               THEN true 
               ELSE false 
             END as is_overdue,
             assignee.first_name as assignee_first_name,
             assignee.last_name as assignee_last_name
      FROM tasks t
      LEFT JOIN (
        SELECT task_id, SUM(duration_minutes) as total_time_minutes
        FROM time_entries 
        WHERE end_time IS NOT NULL
        GROUP BY task_id
      ) te ON t.id = te.task_id
      LEFT JOIN users assignee ON t.assigned_to = assignee.id
      WHERE (t.user_id = $1 OR (t.assigned_to = $1 AND $4 = true))
      AND (
        t.title ILIKE $2 
        OR t.description ILIKE $2 
        OR t.category ILIKE $2
        OR $3 = ANY(t.tags)
      )
    `;

    const values = [userId, `%${searchTerm}%`, searchTerm, options.includeAssigned !== false];

    if (options.status) {
      query += ` AND t.status = $5`;
      values.push(options.status);
    }

    query += ` ORDER BY t.updated_at DESC`;

    if (options.limit) {
      query += ` LIMIT $${values.length + 1}`;
      values.push(options.limit);
    }

    const result = await pool.query(query, values);
    return result.rows;
  }
}

module.exports = Task;