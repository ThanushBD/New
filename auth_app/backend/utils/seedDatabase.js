const pool = require('../config/database');
const bcrypt = require('bcryptjs');

const seedDatabase = async () => {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    console.log('🌱 Starting database seeding...');
    
    // Create sample user
    const hashedPassword = await bcrypt.hash('password123', 12);
    const userResult = await client.query(`
      INSERT INTO users (email, password, first_name, last_name, email_verified, avatar_url)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (email) DO UPDATE SET
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name
      RETURNING id, email, first_name, last_name
    `, [
      'demo@taskflow.app',
      hashedPassword,
      'Demo',
      'User',
      true,
      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&crop=face'
    ]);
    
    const userId = userResult.rows[0].id;
    console.log('✅ Created demo user:', userResult.rows[0]);
    
    // Create sample categories (will be created automatically by trigger, but let's update them)
    const categories = [
      { name: 'Development', color: '#2196F3', icon: 'code' },
      { name: 'Design', color: '#9C27B0', icon: 'palette' },
      { name: 'Meeting', color: '#FF9800', icon: 'people' },
      { name: 'Documentation', color: '#4CAF50', icon: 'description' },
      { name: 'Research', color: '#607D8B', icon: 'search' },
      { name: 'Testing', color: '#F44336', icon: 'bug_report' },
      { name: 'Marketing', color: '#E91E63', icon: 'campaign' },
      { name: 'General', color: '#667eea', icon: 'folder' }
    ];
    
    for (const category of categories) {
      await client.query(`
        INSERT INTO categories (user_id, name, color, icon)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (user_id, name) DO UPDATE SET
          color = EXCLUDED.color,
          icon = EXCLUDED.icon
      `, [userId, category.name, category.color, category.icon]);
    }
    console.log('✅ Created/updated categories');
    
    // Create sample tasks
    const tasks = [
      {
        title: 'Complete Flutter Authentication App',
        description: 'Finish implementing all authentication features including Google Sign-In, email verification, and password reset functionality.',
        priority: 'high',
        status: 'in_progress',
        category: 'Development',
        tags: ['flutter', 'authentication', 'mobile'],
        estimatedMinutes: 480,
        actualMinutes: 240,
        dueDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000) // 3 days from now
      },
      {
        title: 'Design Task Management UI',
        description: 'Create wireframes and mockups for the task management interface with focus on user experience.',
        priority: 'medium',
        status: 'completed',
        category: 'Design',
        tags: ['ui', 'ux', 'wireframes'],
        estimatedMinutes: 240,
        actualMinutes: 180,
        dueDate: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000), // 2 days ago
        completedAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000) // 1 day ago
      },
      {
        title: 'Write API Documentation',
        description: 'Document all REST API endpoints with examples and response formats.',
        priority: 'medium',
        status: 'pending',
        category: 'Documentation',
        tags: ['api', 'documentation', 'rest'],
        estimatedMinutes: 180,
        dueDate: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000) // 5 days from now
      },
      {
        title: 'Implement Time Tracking',
        description: 'Add timer functionality with start/stop capabilities and time entry management.',
        priority: 'high',
        status: 'in_progress',
        category: 'Development',
        tags: ['timer', 'tracking', 'backend'],
        estimatedMinutes: 360,
        actualMinutes: 120,
        dueDate: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000) // 2 days from now
      },
      {
        title: 'Setup Database Schema',
        description: 'Create and optimize database tables for tasks, time entries, and user management.',
        priority: 'urgent',
        status: 'completed',
        category: 'Development',
        tags: ['database', 'postgresql', 'schema'],
        estimatedMinutes: 120,
        actualMinutes: 90,
        dueDate: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000), // 3 days ago
        completedAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000) // 2 days ago
      },
      {
        title: 'Team Standup Meeting',
        description: 'Daily standup to discuss progress and blockers.',
        priority: 'low',
        status: 'completed',
        category: 'Meeting',
        tags: ['standup', 'team', 'daily'],
        estimatedMinutes: 30,
        actualMinutes: 25,
        dueDate: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000), // 1 day ago
        completedAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000) // 1 day ago
      },
      {
        title: 'Research React Native Integration',
        description: 'Investigate possibilities for cross-platform mobile development.',
        priority: 'low',
        status: 'pending',
        category: 'Research',
        tags: ['react-native', 'mobile', 'cross-platform'],
        estimatedMinutes: 240,
        dueDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 1 week from now
      },
      {
        title: 'Write Unit Tests',
        description: 'Create comprehensive test suite for all API endpoints.',
        priority: 'medium',
        status: 'pending',
        category: 'Testing',
        tags: ['testing', 'jest', 'api'],
        estimatedMinutes: 300,
        dueDate: new Date(Date.now() + 4 * 24 * 60 * 60 * 1000) // 4 days from now
      }
    ];
    
    const taskIds = [];
    for (const task of tasks) {
      const taskResult = await client.query(`
        INSERT INTO tasks (
          user_id, title, description, priority, status, category, 
          tags, estimated_minutes, actual_minutes, due_date, completed_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        RETURNING id, title
      `, [
        userId,
        task.title,
        task.description,
        task.priority,
        task.status,
        task.category,
        task.tags,
        task.estimatedMinutes,
        task.actualMinutes,
        task.dueDate,
        task.completedAt || null
      ]);
      
      taskIds.push({
        id: taskResult.rows[0].id,
        title: taskResult.rows[0].title,
        category: task.category,
        status: task.status
      });
    }
    console.log('✅ Created sample tasks:', taskIds.length);
    
    // Create sample time entries
    const timeEntries = [
      {
        taskId: taskIds.find(t => t.title.includes('Flutter Authentication'))?.id,
        startTime: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000 + 9 * 60 * 60 * 1000), // 2 days ago, 9 AM
        endTime: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000 + 11 * 60 * 60 * 1000), // 2 days ago, 11 AM
        description: 'Implemented login screen with animations',
        category: 'Development'
      },
      {
        taskId: taskIds.find(t => t.title.includes('Flutter Authentication'))?.id,
        startTime: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000 + 14 * 60 * 60 * 1000), // 2 days ago, 2 PM
        endTime: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000 + 16 * 60 * 60 * 1000), // 2 days ago, 4 PM
        description: 'Added Google Sign-In integration',
        category: 'Development'
      },
      {
        taskId: taskIds.find(t => t.title.includes('Design Task Management'))?.id,
        startTime: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000 + 10 * 60 * 60 * 1000), // 3 days ago, 10 AM
        endTime: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000 + 13 * 60 * 60 * 1000), // 3 days ago, 1 PM
        description: 'Created wireframes for task list interface',
        category: 'Design'
      },
      {
        taskId: taskIds.find(t => t.title.includes('Database Schema'))?.id,
        startTime: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000 + 15 * 60 * 60 * 1000), // 4 days ago, 3 PM
        endTime: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000 + 16 * 60 * 30 * 1000), // 4 days ago, 4:30 PM
        description: 'Set up PostgreSQL tables and relationships',
        category: 'Development'
      },
      {
        taskId: taskIds.find(t => t.title.includes('Team Standup'))?.id,
        startTime: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000 + 9 * 60 * 60 * 1000), // 1 day ago, 9 AM
        endTime: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000 + 9 * 60 * 25 * 1000), // 1 day ago, 9:25 AM
        description: 'Daily standup - discussed API progress',
        category: 'Meeting'
      },
      {
        taskId: taskIds.find(t => t.title.includes('Time Tracking'))?.id,
        startTime: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000 + 10 * 60 * 60 * 1000), // 1 day ago, 10 AM
        endTime: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000 + 12 * 60 * 60 * 1000), // 1 day ago, 12 PM
        description: 'Implemented timer start/stop functionality',
        category: 'Development'
      },
      // Today's entries
      {
        taskId: taskIds.find(t => t.title.includes('Flutter Authentication'))?.id,
        startTime: new Date(Date.now() - 2 * 60 * 60 * 1000), // 2 hours ago
        endTime: new Date(Date.now() - 30 * 60 * 1000), // 30 minutes ago
        description: 'Added forgot password functionality',
        category: 'Development'
      },
      {
        taskId: taskIds.find(t => t.title.includes('API Documentation'))?.id,
        startTime: new Date(Date.now() - 4 * 60 * 60 * 1000), // 4 hours ago
        endTime: new Date(Date.now() - 3 * 60 * 60 * 1000), // 3 hours ago
        description: 'Started documenting authentication endpoints',
        category: 'Documentation'
      }
    ];
    
    for (const entry of timeEntries) {
      if (entry.taskId) {
        const task = taskIds.find(t => t.id === entry.taskId);
        await client.query(`
          INSERT INTO time_entries (
            user_id, task_id, task_title, start_time, end_time, 
            description, category, is_running
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        `, [
          userId,
          entry.taskId,
          task?.title || 'Unknown Task',
          entry.startTime,
          entry.endTime,
          entry.description,
          entry.category,
          false
        ]);
      }
    }
    console.log('✅ Created sample time entries:', timeEntries.length);
    
    // Calculate and insert daily statistics
    const today = new Date();
    const dates = [];
    for (let i = 7; i >= 0; i--) {
      const date = new Date(today);
      date.setDate(date.getDate() - i);
      dates.push(date);
    }
    
    for (const date of dates) {
      await client.query('SELECT calculate_daily_statistics($1, $2)', [userId, date.toISOString().split('T')[0]]);
    }
    console.log('✅ Calculated daily statistics for past 8 days');
    
    await client.query('COMMIT');
    console.log('🎉 Database seeding completed successfully!');
    console.log(`
📊 Demo Data Created:
• Demo User: demo@taskflow.app (password: password123)
• Categories: ${categories.length}
• Tasks: ${tasks.length}
• Time Entries: ${timeEntries.length}
• Daily Statistics: ${dates.length} days

🚀 You can now test the application with pre-populated data!
    `);
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Error seeding database:', error);
    throw error;
  } finally {
    client.release();
  }
};

// Run seeding if called directly
if (require.main === module) {
  seedDatabase()
    .then(() => {
      console.log('✅ Seeding completed');
      process.exit(0);
    })
    .catch((error) => {
      console.error('❌ Seeding failed:', error);
      process.exit(1);
    });
}

module.exports = seedDatabase;