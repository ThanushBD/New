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

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks(created_at);

CREATE INDEX IF NOT EXISTS idx_time_entries_user_id ON time_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_time_entries_task_id ON time_entries(task_id);
CREATE INDEX IF NOT EXISTS idx_time_entries_start_time ON time_entries(start_time);
CREATE INDEX IF NOT EXISTS idx_time_entries_is_running ON time_entries(is_running);

CREATE INDEX IF NOT EXISTS idx_active_timers_user_id ON active_timers(user_id);
CREATE INDEX IF NOT EXISTS idx_categories_user_id ON categories(user_id);
CREATE INDEX IF NOT EXISTS idx_user_statistics_user_date ON user_statistics(user_id, date);

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

-- Function to update task actual minutes when time entry is completed
CREATE OR REPLACE FUNCTION update_task_actual_minutes()
RETURNS TRIGGER AS $$
BEGIN
    -- Update actual minutes for the task
    UPDATE tasks 
    SET actual_minutes = (
        SELECT COALESCE(SUM(duration_minutes), 0)
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

-- Insert sample data (optional - for testing)
-- This will be handled by the application, but keeping here for reference

-- Views for common queries
CREATE OR REPLACE VIEW task_summary AS
SELECT 
    t.*,
    u.first_name,
    u.last_name,
    COALESCE(te.total_time_minutes, 0) as total_logged_time,
    CASE 
        WHEN t.due_date IS NOT NULL AND t.due_date < CURRENT_TIMESTAMP AND t.status != 'completed'
        THEN true 
        ELSE false 
    END as is_overdue
FROM tasks t
JOIN users u ON t.user_id = u.id
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

