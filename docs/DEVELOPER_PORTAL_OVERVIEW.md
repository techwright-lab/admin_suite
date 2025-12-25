# Developer Portal Overview

The Developer Portal is the admin interface for managing all application resources. It's built on a declarative DSL framework that makes it easy to add new resources and customize existing ones.

## Access

The portal is available at `/internal/developer` and requires admin authentication.

## Architecture

### Three Portals

The Developer Portal is divided into three specialized portals:

| Portal | Path | Purpose |
|--------|------|---------|
| **Ops Portal** | `/internal/developer/ops` | Content management, users, email, scraping |
| **AI Portal** | `/internal/developer/ai` | LLM prompts, provider configs, API logs |
| **Assistant Portal** | `/internal/developer/assistant` | Chat threads, tools, memory management |

### Key Components

```
app/
├── admin/
│   ├── base/
│   │   └── resource.rb          # Base DSL for resource definitions
│   └── resources/
│       └── *.rb                 # Resource definitions (one per model)
├── controllers/
│   └── internal/developer/
│       ├── base_controller.rb   # Authentication & common setup
│       ├── resources_controller.rb  # Generic CRUD operations
│       ├── ops/                 # Ops portal controllers
│       ├── ai/                  # AI portal controllers
│       └── assistant/           # Assistant portal controllers
└── views/
    └── internal/developer/
        ├── resources/           # Generic views (index, show, edit, new, merge)
        ├── shared/              # Shared partials (sidebar, topbar, form)
        └── docs/                # Documentation viewer
```

## Features

### Index Pages
- **Search**: Full-text search across configurable fields (3+ characters required)
- **Filters**: Select, toggle, date range filters
- **Sorting**: Clickable column headers with sort indicators
- **Pagination**: Configurable items per page
- **Stats**: Dashboard stats at the top of each resource

### Show Pages
- **Two-column layout**: Sidebar for metadata, main area for content
- **Associations**: Configurable display (list, table, cards)
- **Actions**: Member actions (enable, disable, merge, etc.)
- **JSON/Code viewing**: Syntax highlighting for JSON and code fields

### Forms
- **Field types**: Text, textarea, select, searchable select, toggle, file upload, markdown, JSON editor
- **Validation**: Required fields, help text, placeholders
- **File uploads**: Active Storage integration with preview

### Actions
- **Toggle**: Enable/disable boolean fields
- **Merge**: Merge duplicate records into a target
- **Custom actions**: Publish, unpublish, approve, etc.

## Resource Count by Portal

### Ops Portal (18 resources)
- Companies, Job Roles, Categories, Skill Tags
- Job Listings, Interview Applications, Interview Rounds, Company Feedbacks
- Blog Posts
- Users, Connected Accounts, Support Tickets
- Email Senders, Synced Emails
- Scraping Attempts, Scraping Events, HTML Scraping Logs
- Settings

### AI Portal (3 resources)
- LLM Prompts
- LLM Provider Configs
- LLM API Logs

### Assistant Portal (8 resources)
- Threads, Turns, Events
- Tools, Tool Executions
- Memory Proposals, Thread Summaries, User Memories

## Technology Stack

- **Backend**: Rails 8.0 with Hotwire (Turbo + Stimulus)
- **Styling**: Tailwind CSS with dark mode support
- **Pagination**: Pagy gem
- **Forms**: Dynamic field rendering with Stimulus controllers
- **Routing**: Modular route files with concerns

## Related Documentation

- [Adding New Resources](./DEVELOPER_PORTAL_ADDING_RESOURCES.md) - Guide for adding new admin resources
- [Assistant Overview](./ASSISTANT_OVERVIEW.md) - Assistant system documentation

