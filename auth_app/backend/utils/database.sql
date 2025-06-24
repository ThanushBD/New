-- Updated database schema with task management and time tracking

-- Create users table (existing - with modifications)
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE,
    avatar_url TEXT,
    reset_token VARCHAR(255),
    reset_token_expires TIMESTAMP,
    verification_token VARCHAR(255),
    email_verified BOOLEAN DEFAULT FALSE,
    google_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT DEFAULT '',
    priority VARCHAR(20) NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
    category VARCHAR(100) DEFAULT 'General',
    tags TEXT[] DEFAULT '{}',
    estimated_minutes INTEGER DEFAULT 60,
    actual_minutes INTEGER DEFAULT 0,
    estimated_hours DECIMAL(5,2) DEFAULT 1.0,
    actual_hours DECIMAL(5,2) DEFAULT 0.0,
    assigned_by INTEGER REFERENCES users(id),
    assigned_to INTEGER REFERENCES users(id),
    start_date TIMESTAMP,
    due_date TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create time_entries table
CREATE TABLE IF NOT EXISTS time_entries (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    task_title VARCHAR(255) NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    description TEXT DEFAULT '',
    category VARCHAR(100) DEFAULT 'General',
    is_running BOOLEAN DEFAULT FALSE,
    duration_minutes INTEGER GENERATED ALWAYS AS (
        CASE 
            WHEN end_time IS NOT NULL THEN 
                EXTRACT(EPOCH FROM (end_time - start_time))/60
            ELSE 0
        END
    ) STORED,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create active_timers table (for tracking currently running timers)
CREATE TABLE IF NOT EXISTS active_timers (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    task_title VARCHAR(255) NOT NULL,
    start_time TIMESTAMP NOT NULL,
    description TEXT DEFAULT '',
    category VARCHAR(100) DEFAULT 'General',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id) -- Only one active timer per user
);

-- Create categories table
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    color VARCHAR(7) DEFAULT '#667eea', -- Hex color code
    icon VARCHAR(50) DEFAULT 'folder',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, name)
);

-- Create user_statistics table (for caching statistics)
CREATE TABLE IF NOT EXISTS user_statistics (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    total_tasks INTEGER DEFAULT 0,
    completed_tasks INTEGER DEFAULT 0,
    total_time_minutes INTEGER DEFAULT 0,
    productivity_score DECIMAL(5,2) DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, date)
);

-- Create task_assignments table for better tracking
CREATE TABLE IF NOT EXISTS task_assignments (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    assigned_by INTEGER NOT NULL REFERENCES users(id),
    assigned_to INTEGER NOT NULL REFERENCES users(id),
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    accepted_at TIMESTAMP,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'reassigned')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create task_collaborators table for multiple assignees
CREATE TABLE IF NOT EXISTS task_collaborators (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'assignee' CHECK (role IN ('assignee', 'reviewer', 'observer')),
    added_by INTEGER NOT NULL REFERENCES users(id),
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(task_id, user_id)
);

-- Create notifications table for task assignments
CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id INTEGER REFERENCES tasks(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks(created_at);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to ON tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_by ON tasks(assigned_by);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to_status ON tasks(assigned_to, status);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_by_status ON tasks(assigned_by, status);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date_status ON tasks(due_date, status);

CREATE INDEX IF NOT EXISTS idx_time_entries_user_id ON time_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_time_entries_task_id ON time_entries(task_id);
CREATE INDEX IF NOT EXISTS idx_time_entries_start_time ON time_entries(start_time);
CREATE INDEX IF NOT EXISTS idx_time_entries_is_running ON time_entries(is_running);

CREATE INDEX IF NOT EXISTS idx_active_timers_user_id ON active_timers(user_id);
CREATE INDEX IF NOT EXISTS idx_categories_user_id ON categories(user_id);
CREATE INDEX IF NOT EXISTS idx_user_statistics_user_date ON user_statistics(user_id, date);
CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_to ON task_assignments(assigned_to);
CREATE INDEX IF NOT EXISTS idx_task_assignments_status ON task_assignments(status);
CREATE INDEX IF NOT EXISTS idx_task_collaborators_user_id ON task_collaborators(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_type ON notifications(user_id, type);

-- Create triggers for updating timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers to tables
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_tasks_updated_at ON tasks;
CREATE TRIGGER update_tasks_updated_at 
    BEFORE UPDATE ON tasks 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_time_entries_updated_at ON time_entries;
CREATE TRIGGER update_time_entries_updated_at 
    BEFORE UPDATE ON time_entries 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_statistics_updated_at ON user_statistics;
CREATE TRIGGER update_user_statistics_updated_at 
    BEFORE UPDATE ON user_statistics 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Function to sync estimated hours and minutes
CREATE OR REPLACE FUNCTION sync_estimated_hours()
RETURNS TRIGGER AS $$
BEGIN
    -- If estimated_hours is not provided but estimated_minutes is, calculate it
    IF NEW.estimated_hours IS NULL AND NEW.estimated_minutes IS NOT NULL THEN
        NEW.estimated_hours := NEW.estimated_minutes / 60.0;
    END IF;
    
    -- If estimated_minutes is not provided but estimated_hours is, calculate it
    IF NEW.estimated_minutes IS NULL AND NEW.estimated_hours IS NOT NULL THEN
        NEW.estimated_minutes := NEW.estimated_hours * 60;
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger for syncing estimated hours and minutes
DROP TRIGGER IF EXISTS sync_estimated_hours_trigger ON tasks;
CREATE TRIGGER sync_estimated_hours_trigger
    BEFORE INSERT OR UPDATE ON tasks
    FOR EACH ROW
    EXECUTE FUNCTION sync_estimated_hours();

-- Function to update task actual minutes when time entry is completed
CREATE OR REPLACE FUNCTION update_task_actual_minutes()
RETURNS TRIGGER AS $$
BEGIN
    -- Update actual minutes for the task
    UPDATE tasks 
    SET 
        actual_minutes = (
            SELECT COALESCE(SUM(duration_minutes), 0)
            FROM time_entries 
            WHERE task_id = NEW.task_id AND end_time IS NOT NULL
        ),
        actual_hours = (
            SELECT COALESCE(SUM(duration_minutes), 0) / 60.0
            FROM time_entries 
            WHERE task_id = NEW.task_id AND end_time IS NOT NULL
        )
    WHERE id = NEW.task_id;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger for updating task actual minutes
DROP TRIGGER IF EXISTS update_task_minutes_trigger ON time_entries;
CREATE TRIGGER update_task_minutes_trigger
    AFTER INSERT OR UPDATE ON time_entries
    FOR EACH ROW
    EXECUTE FUNCTION update_task_actual_minutes();

-- Insert default categories for new users
CREATE OR REPLACE FUNCTION create_default_categories()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO categories (user_id, name, color, icon) VALUES
        (NEW.id, 'Development', '#2196F3', 'code'),
        (NEW.id, 'Design', '#9C27B0', 'palette'),
        (NEW.id, 'Meeting', '#FF9800', 'people'),
        (NEW.id, 'Documentation', '#4CAF50', 'description'),
        (NEW.id, 'General', '#667eea', 'folder');
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger for creating default categories
DROP TRIGGER IF EXISTS create_default_categories_trigger ON users;
CREATE TRIGGER create_default_categories_trigger
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION create_default_categories();

-- Function to calculate daily statistics
CREATE OR REPLACE FUNCTION calculate_daily_statistics(p_user_id INTEGER, p_date DATE)
RETURNS VOID AS $$
DECLARE
    v_total_tasks INTEGER;
    v_completed_tasks INTEGER;
    v_total_time_minutes INTEGER;
    v_productivity_score DECIMAL(5,2);
BEGIN
    -- Get task counts for the date
    SELECT 
        COUNT(*) FILTER (WHERE DATE(created_at) = p_date),
        COUNT(*) FILTER (WHERE DATE(completed_at) = p_date)
    INTO v_total_tasks, v_completed_tasks
    FROM tasks 
    WHERE user_id = p_user_id;
    
    -- Get total time for the date
    SELECT COALESCE(SUM(duration_minutes), 0)
    INTO v_total_time_minutes
    FROM time_entries 
    WHERE user_id = p_user_id 
    AND DATE(start_time) = p_date 
    AND end_time IS NOT NULL;
    
    -- Calculate productivity score (simple formula)
    v_productivity_score := CASE 
        WHEN v_total_tasks > 0 THEN 
            (v_completed_tasks::DECIMAL / v_total_tasks) * 100
        ELSE 0
    END;
    
    -- Insert or update statistics
    INSERT INTO user_statistics (user_id, date, total_tasks, completed_tasks, total_time_minutes, productivity_score)
    VALUES (p_user_id, p_date, v_total_tasks, v_completed_tasks, v_total_time_minutes, v_productivity_score)
    ON CONFLICT (user_id, date) 
    DO UPDATE SET 
        total_tasks = EXCLUDED.total_tasks,
        completed_tasks = EXCLUDED.completed_tasks,
        total_time_minutes = EXCLUDED.total_time_minutes,
        productivity_score = EXCLUDED.productivity_score,
        updated_at = CURRENT_TIMESTAMP;
END;
$$ language 'plpgsql';

-- Function to get available users with details
CREATE OR REPLACE FUNCTION get_available_users(current_user_id INTEGER)
RETURNS TABLE (
    id INTEGER,
    email VARCHAR(255),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    avatar_url TEXT,
    full_name TEXT,
    email_verified BOOLEAN,
    active_tasks_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.email,
        u.first_name,
        u.last_name,
        u.avatar_url,
        CONCAT(u.first_name, ' ', u.last_name) as full_name,
        u.email_verified,
        COALESCE(task_counts.active_count, 0) as active_tasks_count
    FROM users u
    LEFT JOIN (
        SELECT 
            assigned_to,
            COUNT(*) as active_count
        FROM tasks 
        WHERE status IN ('pending', 'in_progress') 
        AND assigned_to IS NOT NULL
        GROUP BY assigned_to
    ) task_counts ON u.id = task_counts.assigned_to
    WHERE u.id != current_user_id 
    AND u.email_verified = true
    ORDER BY u.first_name, u.last_name;
END;
$$ LANGUAGE plpgsql;

-- CORRECTED: Function to create task with assignment
CREATE OR REPLACE FUNCTION create_task_with_assignment(
    p_user_id INTEGER,
    p_title VARCHAR(255),
    p_description TEXT,
    p_assigned_by INTEGER,
    p_assigned_to INTEGER,
    p_priority VARCHAR(20),
    p_category VARCHAR(100),
    p_estimated_hours DECIMAL(5,2),
    p_start_date TIMESTAMP,
    p_due_date TIMESTAMP,
    p_tags TEXT[]
)
RETURNS TABLE(
    task_id INTEGER,
    task_title VARCHAR(255),
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    v_task_id INTEGER;
    v_assignee_name TEXT;
BEGIN
    -- Validate that assigned_to user exists and is verified
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_assigned_to 
        AND email_verified = true
    ) THEN
        RETURN QUERY SELECT NULL::INTEGER, NULL::VARCHAR(255), false, 'Assigned user not found or not verified'::TEXT;
        RETURN;
    END IF;
    
    -- Create the task
    INSERT INTO tasks (
        user_id, title, description, assigned_by, assigned_to, priority, 
        category, estimated_hours, estimated_minutes, start_date, due_date, tags, status
    )
    VALUES (
        p_user_id, p_title, p_description, p_assigned_by, p_assigned_to, 
        p_priority, p_category, p_estimated_hours, p_estimated_hours * 60,
        p_start_date, p_due_date, p_tags, 'pending'
    )
    RETURNING id INTO v_task_id;
    
    -- Create assignment record
    INSERT INTO task_assignments (task_id, assigned_by, assigned_to)
    VALUES (v_task_id, p_assigned_by, p_assigned_to);
    
    -- Get assignee name for notification
    SELECT CONCAT(first_name, ' ', last_name) INTO v_assignee_name
    FROM users WHERE id = p_assigned_to;
    
    -- Create notification for assignee
    INSERT INTO notifications (user_id, task_id, type, title, message)
    VALUES (
        p_assigned_to,
        v_task_id,
        'task_assigned',
        'New Task Assigned',
        'You have been assigned a new task: ' || p_title
    );
    
    RETURN QUERY SELECT v_task_id, p_title, true, 'Task created and assigned successfully'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Function to get enhanced task statistics with assignment info
CREATE OR REPLACE FUNCTION get_enhanced_task_statistics(p_user_id INTEGER)
RETURNS TABLE(
    total_tasks BIGINT,
    completed_tasks BIGINT,
    in_progress_tasks BIGINT,
    pending_tasks BIGINT,
    assigned_to_me BIGINT,
    assigned_by_me BIGINT,
    overdue_tasks BIGINT,
    total_time_minutes NUMERIC,
    completion_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) FILTER (WHERE t.user_id = p_user_id OR t.assigned_to = p_user_id) as total_tasks,
        COUNT(*) FILTER (WHERE t.status = 'completed' AND (t.user_id = p_user_id OR t.assigned_to = p_user_id)) as completed_tasks,
        COUNT(*) FILTER (WHERE t.status = 'in_progress' AND (t.user_id = p_user_id OR t.assigned_to = p_user_id)) as in_progress_tasks,
        COUNT(*) FILTER (WHERE t.status = 'pending' AND (t.user_id = p_user_id OR t.assigned_to = p_user_id)) as pending_tasks,
        COUNT(*) FILTER (WHERE t.assigned_to = p_user_id) as assigned_to_me,
        COUNT(*) FILTER (WHERE t.assigned_by = p_user_id) as assigned_by_me,
        COUNT(*) FILTER (WHERE t.due_date IS NOT NULL AND t.due_date < CURRENT_TIMESTAMP AND t.status != 'completed' AND (t.user_id = p_user_id OR t.assigned_to = p_user_id)) as overdue_tasks,
        COALESCE(SUM(te.duration_minutes) FILTER (WHERE DATE(te.start_time) = CURRENT_DATE), 0) as total_time_minutes,
        ROUND(
            (COUNT(*) FILTER (WHERE t.status = 'completed' AND (t.user_id = p_user_id OR t.assigned_to = p_user_id))::DECIMAL / 
             NULLIF(COUNT(*) FILTER (WHERE t.user_id = p_user_id OR t.assigned_to = p_user_id), 0)) * 100, 
            2
        ) as completion_rate
    FROM tasks t
    LEFT JOIN time_entries te ON t.id = te.task_id AND te.user_id = p_user_id
    WHERE t.user_id = p_user_id OR t.assigned_to = p_user_id OR t.assigned_by = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get notifications with task details
CREATE OR REPLACE FUNCTION get_user_notifications(p_user_id INTEGER, p_limit INTEGER DEFAULT 50)
RETURNS TABLE(
    id INTEGER,
    task_id INTEGER,
    task_title VARCHAR(255),
    type VARCHAR(50),
    title VARCHAR(255),
    message TEXT,
    is_read BOOLEAN,
    created_at TIMESTAMP,
    task_priority VARCHAR(20),
    task_due_date TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.id,
        n.task_id,
        t.title as task_title,
        n.type,
        n.title,
        n.message,
        n.is_read,
        n.created_at,
        t.priority as task_priority,
        t.due_date as task_due_date
    FROM notifications n
    LEFT JOIN tasks t ON n.task_id = t.id
    WHERE n.user_id = p_user_id
    ORDER BY n.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Views for common queries
CREATE OR REPLACE VIEW task_summary AS
SELECT 
    t.*,
    creator.first_name as creator_first_name,
    creator.last_name as creator_last_name,
    creator.email as creator_email,
    creator.avatar_url as creator_avatar,
    assignee.first_name as assignee_first_name,
    assignee.last_name as assignee_last_name,
    assignee.email as assignee_email,
    assignee.avatar_url as assignee_avatar,
    CONCAT(assignee.first_name, ' ', assignee.last_name) as assignee_full_name,
    CONCAT(creator.first_name, ' ', creator.last_name) as creator_full_name,
    COALESCE(te.total_time_minutes, 0) as total_logged_time,
    CASE 
        WHEN t.due_date IS NOT NULL AND t.due_date < CURRENT_TIMESTAMP AND t.status != 'completed'
        THEN true 
        ELSE false 
    END as is_overdue,
    CASE 
        WHEN t.start_date IS NOT NULL AND t.start_date <= CURRENT_TIMESTAMP AND t.status = 'pending'
        THEN true 
        ELSE false 
    END as should_start,
    ta.status as assignment_status,
    ta.assigned_at,
    ta.accepted_at
FROM tasks t
LEFT JOIN users creator ON t.assigned_by = creator.id
LEFT JOIN users assignee ON t.assigned_to = assignee.id
LEFT JOIN task_assignments ta ON t.id = ta.task_id
LEFT JOIN (
    SELECT 
        task_id, 
        SUM(duration_minutes) as total_time_minutes
    FROM time_entries 
    WHERE end_time IS NOT NULL
    GROUP BY task_id
) te ON t.id = te.task_id;

CREATE OR REPLACE VIEW daily_time_summary AS
SELECT 
    user_id,
    DATE(start_time) as date,
    COUNT(*) as session_count,
    SUM(duration_minutes) as total_minutes,
    AVG(duration_minutes) as avg_minutes,
    MIN(start_time) as first_session,
    MAX(end_time) as last_session
FROM time_entries 
WHERE end_time IS NOT NULL
GROUP BY user_id, DATE(start_time);