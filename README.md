# Lovebomb

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix


# LoveBomb - Relationship Building Application

## Overview
LoveBomb is a relationship-building application designed to deepen connections between partners through daily questions, shared answers, and interactive features. The application consists of three main interfaces:
1. RESTful API for mobile applications
2. LiveView web interface for direct user access
3. Admin interface for content and user management

## Core Features

### User System
- Complete authentication system using JWT for API and session-based auth for web
- User profiles with customizable information
- Multi-partner support (users can connect with multiple partners)
- User statistics tracking (scores, streaks, levels, questions answered)
- Privacy settings and preferences management
- Avatar upload and management
- Email notifications and preferences
- Activity tracking and analytics

### Partnership System
- Bi-directional partnership management
- Partnership status tracking (pending, active, inactive, blocked)
- Partnership levels that increase with interaction
- Partnership-specific settings and preferences
- Interaction history and statistics
- Custom nicknames and settings per partnership
- Achievement system for partnership milestones
- Real-time notifications for partnership activities

### Question System
- Dynamic difficulty levels (1-100)
- Categorized questions with tags
- Question scoring system
- Daily question assignment based on user level
- No question repetition for users
- Question metadata including follow-up questions and suggested topics
- Difficulty adjustment based on user responses
- Multi-language support for questions
- Question statistics and performance tracking

### Answer System
- Daily answer requirement
- Skip functionality with reason tracking
- Answer visibility controls (partners only/public)
- Partner answer notifications
- Reaction system for answers (emoji reactions)
- Answer statistics and analytics
- Response time tracking
- Word count and language detection
- Edit history tracking

### Level Progression
- User level system based on question completion
- Category-based progression tracking
- Streak system with rewards
- Level-appropriate question selection
- Public score system separate from level
- Achievement system tied to progression
- Milestone celebrations and rewards

### Notification System
- Real-time notifications using Phoenix PubSub
- Multiple notification channels (in-app, email, push)
- Customizable notification preferences
- Notification categories for different events
- Read/unread status tracking
- Quiet hours support
- Notification grouping and prioritization

### Statistics & Analytics
- Comprehensive user statistics
- Partnership interaction metrics
- Question performance analytics
- User engagement tracking
- Streak and milestone tracking
- Category performance analysis
- Response pattern analysis

## Technical Architecture

### Database Schema
1. Users Table
   - Basic authentication fields
   - Statistics tracking
   - Streak information
   - Level progression

2. Profiles Table
   - User information
   - Preferences
   - Settings
   - Avatar management

3. Partnerships Table
   - Bi-directional relationships
   - Status tracking
   - Interaction metrics
   - Custom settings

4. Questions Table
   - Question content
   - Difficulty metrics
   - Categories and tags
   - Performance tracking

5. Answers Table
   - Response content
   - Skip tracking
   - Visibility settings
   - Partnership context

6. Notifications Table
   - Multiple notification types
   - Delivery status
   - User preferences
   - Channel management

### API Endpoints

1. Authentication
   - Registration
   - Login
   - Password management
   - Token refresh
   - Session management

2. Profile Management
   - Profile CRUD
   - Settings management
   - Preference updates
   - Avatar handling

3. Partnership Management
   - Partnership CRUD
   - Status updates
   - Settings management
   - Interaction tracking

4. Questions and Answers
   - Daily question retrieval
   - Answer submission
   - History access
   - Statistics retrieval

5. Notifications
   - Preference management
   - Status updates
   - History access
   - Channel configuration

### Security Features
- JWT authentication
- Rate limiting
- CORS protection
- File upload validation
- Privacy controls
- Data encryption
- Access control
- Input validation

### Performance Features
- Caching system
- Background job processing
- Real-time updates
- Optimized queries
- Rate limiting
- Connection pooling
- Error handling

## Future Enhancement Areas
1. Enhanced Analytics
   - Advanced metrics
   - Predictive analysis
   - Engagement scoring
   - Trend analysis

2. Content Management
   - Question generation
   - Dynamic difficulty adjustment
   - Content moderation
   - Multi-language support

3. Social Features
   - Group partnerships
   - Social sharing
   - Community features
   - Public profiles

4. Gamification
   - Advanced achievement system
   - Rewards program
   - Challenges
   - Partner competitions

5. Integration
   - Calendar integration
   - Social media connection
   - External API support
   - Webhook system

## Technical Requirements
- Elixir/Phoenix framework
- PostgreSQL database
- Guardian for JWT
- Phoenix PubSub
- LiveView
- File storage system
- Email delivery service
- Push notification service

## Development Practices
- Test-driven development
- Documentation requirements
- Code review process
- Security review
- Performance monitoring
- Error tracking
- Deployment strategy
- Backup procedures
