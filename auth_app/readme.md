# 🚀 TaskFlow - Complete Task Management & Time Tracking System

A comprehensive full-stack application with Flutter frontend and Node.js backend, featuring advanced task management, time tracking, and analytics.

## 📋 **Table of Contents**

- [Features](#-features)
- [Tech Stack](#-tech-stack)
- [Quick Start](#-quick-start)
- [Project Structure](#-project-structure)
- [Backend Setup](#-backend-setup)
- [Frontend Setup](#-frontend-setup)
- [Docker Deployment](#-docker-deployment)
- [API Documentation](#-api-documentation)
- [Database Schema](#-database-schema)
- [Contributing](#-contributing)
- [License](#-license)

## ✨ **Features**

### 🎯 **Core Features**
- **User Authentication** - Register, login, Google Sign-In, email verification
- **Task Management** - Create, update, delete, organize tasks with priorities
- **Time Tracking** - Start/stop timers, manual time entries, session management
- **Categories & Tags** - Organize tasks with custom categories and tags
- **Analytics Dashboard** - Productivity insights, time breakdowns, progress tracking
- **Responsive Design** - Beautiful UI with smooth animations

### 🔧 **Advanced Features**
- **Offline Support** - Work without internet, sync when connected
- **Real-time Updates** - Live timer updates and data synchronization
- **Export & Reports** - Generate timesheet reports in multiple formats
- **Search & Filtering** - Find tasks and time entries quickly
- **Due Date Tracking** - Never miss deadlines with smart notifications
- **Progress Visualization** - Charts and graphs for productivity insights

### 🛡️ **Security & Performance**
- **JWT Authentication** - Secure token-based authentication
- **Data Encryption** - Sensitive data protection
- **Rate Limiting** - API protection against abuse
- **Caching Strategy** - Optimized performance with smart caching
- **Error Handling** - Comprehensive error management
- **Health Monitoring** - System health checks and monitoring

## 🛠️ **Tech Stack**

### **Frontend (Flutter)**
- **Framework**: Flutter 3.16+
- **Language**: Dart 3.0+
- **State Management**: Built-in StatefulWidget with services
- **HTTP Client**: http package
- **Local Storage**: flutter_secure_storage, shared_preferences
- **Authentication**: google_sign_in
- **UI**: Custom animations and modern design

### **Backend (Node.js)**
- **Runtime**: Node.js 18+
- **Framework**: Express.js 4.18+
- **Database**: PostgreSQL 15+
- **Authentication**: JWT with bcryptjs
- **Caching**: Redis (optional)
- **Email**: Nodemailer with multiple providers
- **Security**: Helmet, CORS, rate limiting
- **Documentation**: Swagger/OpenAPI

### **DevOps & Tools**
- **Containerization**: Docker & Docker Compose
- **Database**: PostgreSQL with advanced features
- **Reverse Proxy**: Nginx (optional)
- **Process Management**: PM2
- **Testing**: Jest for backend
- **Code Quality**: ESLint, Prettier

## 🚀 **Quick Start**

### **Prerequisites**
- Node.js 18+ and npm
- Flutter 3.16+ and Dart 3.0+
- PostgreSQL 15+
- Git
- Docker (optional)

### **1. Clone Repository**
```bash
git clone https://github.com/yourusername/taskflow.git
cd taskflow
```

### **2. Quick Setup with Docker (Recommended)**
```bash
# Copy environment file
cp .env.example .env

# Edit .env with your configuration
nano .env

# Start all services
docker-compose up -d

# Seed database with sample data
docker-compose exec api npm run seed-db

# View logs
docker-compose logs -f api
```

### **3. Access the Application**
- **Backend API**: http://localhost:3000
- **API Documentation**: http://localhost:3000/api-docs
- **Health Check**: http://localhost:3000/health

## 📁 **Project Structure**

```
taskflow/
├── backend/                 # Node.js API server
│   ├── config/             # Database and app configuration
│   ├── controllers/        # Request handlers
│   ├── middleware/         # Custom middleware
│   ├── models/            # Database models
│   ├── routes/            # API routes
│   ├── services/          # Business logic services
│   ├── utils/             # Helper utilities
│   ├── server.js          # Main server file
│   └── package.json       # Dependencies
├── frontend/              # Flutter mobile app
│   ├── lib/
│   │   ├── models/        # Data models
│   │   ├── screens/       # UI screens
│   │   ├── services/      # API and business logic
│   │   ├── utils/         # Helper utilities
│   │   └── main.dart      # App entry point
│   └── pubspec.yaml       # Flutter dependencies
├── docker-compose.yml     # Docker services
├── Dockerfile            # Backend container
├── .env.example          # Environment template
└── README.md            # This file
```

## 🔧 **Backend Setup**

### **1. Manual Setup**
```bash
cd backend

# Install dependencies
npm install

# Setup PostgreSQL database
createdb auth_app
createuser auth_user

# Copy and configure environment
cp .env.example .env
nano .env

# Run database migrations
npm run setup-db

# Seed with sample data
npm run seed-db

# Start development server
npm run dev
```

### **2. Environment Configuration**
Edit `.env` file with your settings:

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=auth_app
DB_USER=auth_user
DB_PASSWORD=your_secure_password

# JWT Secrets (generate secure keys)
JWT_SECRET=your_super_secret_jwt_key_at_least_32_characters_long
JWT_REFRESH_SECRET=your_super_secret_refresh_jwt_key_32_chars

# Email Configuration
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=your_email@gmail.com
EMAIL_PASSWORD=your_app_password

# Google OAuth
GOOGLE_CLIENT_ID=your_google_client_id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your_google_client_secret
```

### **3. Database Schema**
The system automatically creates tables:
- **users** - User authentication and profiles
- **tasks** - Task management with priorities and categories
- **time_entries** - Time tracking sessions
- **active_timers** - Currently running timers
- **categories** - Task organization
- **user_statistics** - Analytics and insights

## 📱 **Frontend Setup**

### **1. Flutter Environment**
```bash
cd frontend

# Get dependencies
flutter pub get

# Configure API endpoint in lib/utils/constants.dart
# For Android emulator: http://10.0.2.2:3000
# For iOS simulator: http://localhost:3000

# Run the app
flutter run
```

### **2. Build for Production**
```bash
# Android
flutter build apk --release

# iOS (macOS only)
flutter build ios --release
```

### **3. Key Configuration Files**
- **`lib/utils/constants.dart`** - API endpoints and app constants
- **`lib/services/api_service.dart`** - HTTP client and API calls
- **`lib/services/task_service.dart`** - Business logic and caching
- **`lib/services/storage_service.dart`** - Local data management

## 🐳 **Docker Deployment**

### **Development Environment**
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f api

# Execute commands in containers
docker-compose exec api npm run seed-db
docker-compose exec postgres psql -U auth_user -d auth_app
```

### **Production Environment**
```bash
# Use production profile
docker-compose --profile production up -d

# With SSL/HTTPS
docker-compose --profile production -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### **Backup & Restore**
```bash
# Create backup
docker-compose --profile backup run db_backup

# Restore from backup
docker-compose exec postgres psql -U auth_user -d auth_app < backups/backup_file.sql
```

## 📚 **API Documentation**

### **Authentication Endpoints**
```
POST /api/auth/register        - User registration
POST /api/auth/login           - User login
POST /api/auth/google          - Google Sign-In
POST /api/auth/forgot-password - Password reset request
POST /api/auth/reset-password  - Password reset confirmation
POST /api/auth/verify-email    - Email verification
POST /api/auth/refresh         - Token refresh
POST /api/auth/logout          - User logout
```

### **Task Management Endpoints**
```
GET    /api/tasks              - Get all tasks (with filtering)
POST   /api/tasks              - Create new task
GET    /api/tasks/:id          - Get specific task
PUT    /api/tasks/:id          - Update task
DELETE /api/tasks/:id          - Delete task
PATCH  /api/tasks/:id/toggle-status - Toggle task status
GET    /api/tasks/recent       - Get recent tasks
GET    /api/tasks/upcoming     - Get upcoming tasks
GET    /api/tasks/statistics   - Get task statistics
```

### **Time Tracking Endpoints**
```
GET    /api/timesheet          - Get time entries
POST   /api/timesheet          - Create time entry
PUT    /api/timesheet/:id      - Update time entry
DELETE /api/timesheet/:id      - Delete time entry
POST   /api/timesheet/timer/start - Start timer
POST   /api/timesheet/timer/stop  - Stop timer
GET    /api/timesheet/timer/active - Get active timer
GET    /api/timesheet/stats/today - Today's statistics
GET    /api/timesheet/stats/weekly - Weekly statistics
GET    /api/timesheet/reports/timesheet - Generate reports
```

### **Query Parameters**
```
# Task filtering
?status=pending,in_progress
?priority=high,urgent
?category=Development
?overdue=true
?search=flutter

# Pagination
?limit=20
?offset=0

# Date filtering
?startDate=2024-01-01
?endDate=2024-12-31
```

## 🗄️ **Database Schema**

### **Key Tables**

#### **Users Table**
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email_verified BOOLEAN DEFAULT FALSE,
    avatar_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### **Tasks Table**
```sql
CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    priority VARCHAR(20) DEFAULT 'medium',
    status VARCHAR(20) DEFAULT 'pending',
    category VARCHAR(100) DEFAULT 'General',
    tags TEXT[],
    estimated_minutes INTEGER DEFAULT 60,
    actual_minutes INTEGER DEFAULT 0,
    due_date TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### **Time Entries Table**
```sql
CREATE TABLE time_entries (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    task_id INTEGER REFERENCES tasks(id),
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    description TEXT,
    category VARCHAR(100),
    is_running BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 🧪 **Testing**

### **Backend Testing**
```bash
# Run all tests
npm test

# Run with coverage
npm run test:coverage

# Run specific test suite
npm test -- --grep "Task Management"
```

### **Frontend Testing**
```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/
```

## 🔧 **Development**

### **Code Quality**
```bash
# Lint backend code
npm run lint

# Format backend code
npm run format

# Analyze Flutter code
flutter analyze

# Format Flutter code
dart format lib/
```

### **Database Operations**
```bash
# Create migration
npm run migrate:create add_new_feature

# Run migrations
npm run migrate:up

# Rollback migration
npm run migrate:down

# Reset database
npm run db:reset
```

## 🚀 **Production Deployment**

### **Environment Setup**
1. **Server Requirements**
   - Ubuntu 20.04+ or CentOS 8+
   - 2+ CPU cores
   - 4GB+ RAM
   - 20GB+ storage

2. **Domain & SSL**
   - Configure domain DNS
   - Setup SSL certificates (Let's Encrypt)
   - Configure Nginx reverse proxy

### **Deployment Steps**
```bash
# Clone repository
git clone https://github.com/yourusername/taskflow.git
cd taskflow

# Copy production environment
cp .env.example .env.production

# Build and start services
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Setup SSL certificates
certbot --nginx -d your-domain.com

# Configure monitoring
docker-compose --profile monitoring up -d
```

## 📊 **Monitoring & Analytics**

### **Health Checks**
- **API Health**: `GET /health`
- **Database Health**: Connection monitoring
- **Redis Health**: Cache status monitoring

### **Logging**
- Application logs in `logs/` directory
- Database query logs (development)
- Nginx access logs
- Error tracking with Sentry (optional)

### **Metrics**
- Response times
- Database performance
- Active users
- Task completion rates
- Time tracking usage

## 🤝 **Contributing**

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit changes**: `git commit -m 'Add amazing feature'`
4. **Push to branch**: `git push origin feature/amazing-feature`
5. **Open Pull Request**

### **Development Guidelines**
- Follow existing code style
- Add tests for new features
- Update documentation
- Use conventional commit messages

## 🔒 **Security**

### **Best Practices Implemented**
- JWT tokens with refresh mechanism
- Password hashing with bcryptjs
- Rate limiting on all endpoints
- Input validation and sanitization
- CORS configuration
- Helmet.js security headers
- SQL injection prevention
- XSS protection

### **Security Checklist**
- [ ] Change default passwords
- [ ] Configure strong JWT secrets
- [ ] Setup SSL/HTTPS
- [ ] Configure firewall
- [ ] Regular security updates
- [ ] Monitor logs for suspicious activity

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- Flutter team for the amazing framework
- Express.js community
- PostgreSQL developers
- All open-source contributors

## 📞 **Support**

- **Documentation**: https://docs.taskflow.app
- **Email Support**: support@taskflow.app
- **GitHub Issues**: https://github.com/yourusername/taskflow/issues
- **Community Discord**: https://discord.gg/taskflow

---

**Happy coding! 🚀**

Made with ❤️ by the TaskFlow Team