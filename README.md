# Gleania - Smart Interview Assistant

Gleania is a smart interview assistant for job candidates, helping them track interviews, reflect on feedback, and gain insights to improve their interview performance.

## Features

### 1. Smart Interview Tracker
- **Dual View Modes**: Switch between Kanban board and list/table hybrid views
- **Interview Stages**: Track interviews through Applied → Interview → Feedback → Offer
- **Rich Cards**: Each interview shows company, role, stage, date, status, AI summary, and skill tags
- **Quick Actions**: Add feedback, edit, or delete interviews with inline actions

### 2. Feedback & Reflection Journal
- **Guided Reflection**: Structured prompts for "What went well?", "What to improve?", etc.
- **AI Summaries**: Automatic generation of insights from your feedback (placeholder implementation)
- **Skill Tagging**: Auto-tag and track skills mentioned in feedback
- **Recommended Actions**: Get personalized suggestions for improvement

### 3. AI Action Assistant
- **Contextual Chat**: Bottom-right floating assistant drawer
- **Smart Queries**: 
  - Summarize recent interviews
  - Generate thank-you emails
  - Get preparation suggestions
  - Identify skills to focus on
- **Context-Aware**: Uses your interview data to provide personalized responses

### 4. Profile & Insights Dashboard
- **Interview Statistics**: Total interviews, offers, feedback count, monthly activity
- **Top Strengths**: Skills that appear in positive feedback
- **Focus Areas**: Skills identified for improvement
- **Journey Timeline**: Visual timeline of your interview progress with sentiment indicators
- **Profile Management**: Update bio, social links, target roles, and experience

## Tech Stack

- **Backend**: Ruby on Rails 8.1
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS v4
- **Database**: PostgreSQL
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **WebSockets**: Solid Cable (Action Cable)
- **Authentication**: Rails built-in authentication with `has_secure_password`

## Getting Started

### Prerequisites

- Ruby 3.x
- PostgreSQL
- Node.js (for importmap)

### Installation

1. Clone the repository
```bash
git clone <repository-url>
cd gleania
```

2. Install dependencies
```bash
bundle install
```

3. Setup database
```bash
bin/rails db:setup
```

This will create the database, run migrations, and seed it with demo data.

### Running the Application

```bash
bin/dev
```

Visit `http://localhost:3000` in your browser.

### Demo Credentials

- **Email**: demo@gleania.com
- **Password**: password123

## Project Structure

```
app/
├── controllers/
│   ├── interviews_controller.rb      # Interview CRUD operations
│   ├── feedback_entries_controller.rb # Feedback management
│   ├── profiles_controller.rb         # User profile & insights
│   └── ai_assistant/
│       └── queries_controller.rb      # AI assistant queries
├── models/
│   ├── user.rb                        # User model with preferences
│   ├── interview.rb                   # Interview tracking
│   ├── feedback_entry.rb              # Feedback & reflections
│   ├── skill_tag.rb                   # Skills tagging
│   └── user_preference.rb             # User settings
├── services/
│   ├── feedback_analysis_service.rb   # AI feedback analysis
│   ├── ai_assistant_service.rb        # AI assistant responses
│   └── profile_insights_service.rb    # Profile statistics
├── views/
│   ├── interviews/                    # Interview views
│   ├── feedback_entries/              # Feedback views
│   ├── profiles/                      # Profile views
│   └── shared/                        # Shared components
└── javascript/
    └── controllers/                   # Stimulus controllers
```

## Features in Detail

### Interview Tracker

The tracker supports two view modes:

1. **Kanban View**: Visual board with columns for each stage
2. **List View**: Table/card hybrid with sortable columns

View preference is saved to localStorage and persists across sessions.

### Feedback System

Guided reflection with color-coded sections:
- ✅ What went well (green)
- 📈 What to improve (blue)
- 💬 Interviewer notes (purple)
- 💭 Self reflection (gray)

### AI Assistant (Placeholder)

Currently implements rule-based responses. Ready for integration with:
- OpenAI GPT-4
- Anthropic Claude
- Other LLM APIs

To implement real AI:
1. Add API credentials to Rails credentials
2. Update `FeedbackAnalysisService` for real analysis
3. Update `AiAssistantService` for LLM integration

### Dark Mode

Full dark mode support with three themes:
- Light
- Dark
- System (auto-detects OS preference)

Toggle via user menu in sidebar.

## Database Schema

**Core Tables:**
- `users` - User accounts with profiles
- `user_preferences` - User settings and preferences
- `interviews` - Interview tracking entries
- `feedback_entries` - Reflection and feedback
- `skill_tags` - Skills taxonomy
- `interview_skill_tags` - Many-to-many join table

**Supporting Tables:**
- `sessions` - User sessions for authentication

## Future Enhancements (V1.1+)

- [ ] Gmail integration for auto-detecting interview emails
- [ ] Real AI integration (OpenAI/Anthropic)
- [ ] CV Tailor Lite - Generate tailored CVs based on feedback
- [ ] Interview reminders and notifications
- [ ] Export functionality (PDF reports)
- [ ] Team/mentor collaboration features
- [ ] Mobile app (React Native)

## Development

### Running Tests

```bash
bin/rails test
```

### Code Quality

```bash
bin/rubocop          # Ruby linting
bin/brakeman         # Security scanning
bin/bundler-audit    # Dependency security
```

### Database Management

```bash
bin/rails db:migrate      # Run migrations
bin/rails db:rollback     # Rollback last migration
bin/rails db:seed         # Seed database
bin/rails db:reset        # Drop, create, migrate, and seed
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.

## Acknowledgments

- Built with Rails 8.0 conventions
- UI inspired by modern SaaS applications
- Tailwind CSS v4 for styling
- Hotwire for seamless interactivity
