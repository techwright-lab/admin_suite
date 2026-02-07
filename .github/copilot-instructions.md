# GitHub Copilot Instructions for AdminSuite

This is a Ruby on Rails engine gem that provides a resource-based admin UI with CRUD operations, search/filter/sort capabilities, a portal/dashboard system, and a built-in Markdown docs viewer.

## Project Overview

AdminSuite is a mountable Rails engine extracted from the Gleania app, designed to be reusable across multiple products. It provides:
- **Portals**: Group resources by portal + section with optional per-portal dashboards
- **Resources DSL**: Declarative configuration for index (columns/filters/stats), form fields, show panels/associations, and actions
- **Docs viewer**: Renders `*.md` files from host app filesystem at `/docs`
- **UI**: Baseline CSS + engine Tailwind build with optional host overrides

## Technology Stack

- **Ruby**: >= 3.2 (supports Ruby 3.2 and 3.3)
- **Rails**: >= 8.0, < 9.0
- **Frontend**: Hotwire (Turbo + Stimulus) + Tailwind CSS
- **Dependencies**:
  - `pagy` (>= 6.0, < 11.0) - pagination
  - `lucide-rails` (~> 0.7) - icon system
  - `redcarpet` (~> 3.6) - Markdown rendering
  - `rouge` (~> 4.7) - syntax highlighting
  - `tailwindcss-ruby` (~> 4.1) - Tailwind CSS compilation

## Repository Structure

```
admin_suite/
├── .github/
│   └── workflows/        # CI and publish workflows
├── app/
│   ├── assets/           # CSS and Tailwind files
│   ├── controllers/      # Engine controllers
│   ├── helpers/          # View helpers
│   ├── models/           # Engine models (if any)
│   └── views/            # Engine views
├── config/               # Engine configuration
├── docs/                 # Engine documentation (Markdown)
├── lib/
│   ├── admin/            # Admin namespace (Base::Resource, etc.)
│   ├── admin_suite/      # Main engine code
│   │   ├── ui/           # UI components and renderers
│   │   ├── configuration.rb
│   │   ├── engine.rb
│   │   └── version.rb
│   └── generators/       # Rails generators (install, scaffold, resource)
└── test/
    ├── dummy/            # Rails dummy app for testing
    ├── integration/      # Integration tests
    └── lib/              # Unit tests
```

## Development Standards

### Ruby Style Guidelines

1. **Frozen String Literals**: All Ruby files must start with `# frozen_string_literal: true`
2. **Code Style**: Follow standard Ruby style guide
   - Use 2-space indentation
   - Use snake_case for methods and variables
   - Use CamelCase for classes and modules
3. **Documentation**: Use YARD-style comments for public APIs
4. **Naming Conventions**:
   - Resources go in `Admin::Resources` namespace
   - Base classes in `Admin::Base` namespace
   - UI components in `AdminSuite::UI` namespace

### Rails Conventions

1. **Engine Structure**: This is a Rails engine, not a full Rails app
2. **Mounting**: The engine mounts at `/internal/admin` by default
3. **Configuration**: Use `AdminSuite.configure` block in host app initializers
4. **Generators**: Provide generators for installation, resources, and scaffolds
5. **Asset Pipeline**: Engine has its own Tailwind build process

### File Organization

1. **Resource Definitions**: Example resources should be in `config/admin_suite/resources/*.rb`
2. **Documentation**: Keep comprehensive docs in `docs/` directory
3. **Tests**: Organized by type:
   - Integration tests in `test/integration/`
   - Unit tests in `test/lib/`
   - Use dummy app in `test/dummy/` for testing engine behavior

## Testing

### Running Tests

```bash
# Run full test suite
bundle exec rake test

# Run with coverage
COVERAGE=true bundle exec rake test

# Run specific test file
bundle exec ruby -I test test/integration/dashboard_test.rb
```

### Test Guidelines

1. **Framework**: Uses Minitest (Rails default)
2. **Coverage**: Code coverage is tracked and reported to Codecov
3. **CI**: Tests run on Ruby 3.2 and 3.3 automatically on PRs
4. **Dummy App**: Use `test/dummy` for integration testing
5. **Test Structure**: Follow existing patterns in test files

### Writing Tests

- Integration tests should test controller actions and views
- Unit tests should test individual classes and modules
- Use fixtures or factories as needed
- Follow AAA pattern (Arrange, Act, Assert)

## Building and Assets

### Tailwind CSS

The engine has its own Tailwind build process:

```bash
# From gem root
cd test/dummy
bin/rails admin_suite:tailwind:build

# In host app during deployment
bin/rails assets:precompile  # Automatically runs Tailwind build
```

**Important**: The Tailwind output goes to `Rails.root/app/assets/builds/admin_suite_tailwind.css` in the host app.

### Dependencies

```bash
# Install dependencies
bundle install

# Update dependencies (use caution)
bundle update
```

## Common Patterns

### Creating a Resource

Resources use a declarative DSL:

```ruby
module Admin
  module Resources
    class UserResource < Admin::Base::Resource
      model ::User
      portal :ops
      section :accounts

      index do
        searchable :email, :name
        sortable :created_at, default: :created_at, direction: :desc
        
        columns do
          column :id
          column :email
          column :created_at
        end
      end

      form do
        field :email, type: :email, required: true
        field :name, required: true
      end

      show do
        panel :details do
          field :id
          field :email
          field :created_at
        end
      end
    end
  end
end
```

### Configuration

Host apps configure AdminSuite in an initializer:

```ruby
# config/initializers/admin_suite.rb
AdminSuite.configure do |config|
  config.authenticate = ->(controller) { ... }
  config.portals = { ops: { label: "Ops", icon: "settings", ... } }
  config.docs_path = Rails.root.join("docs")
end
```

### Generators

```bash
# Install engine
bin/rails g admin_suite:install --mount-path=/internal/admin

# Generate a resource
bin/rails g admin_suite:resource User portal:ops

# Generate full scaffold
bin/rails g admin_suite:scaffold User email:string name:string
```

## Contributing

### Pull Request Process

1. Create a feature branch from `main`
2. Make your changes following the style guidelines
3. Add or update tests as needed
4. Ensure all tests pass: `bundle exec rake test`
5. Push and create a pull request

### CI Requirements

All PRs must pass:
- **Tests**: Automated test suite on Ruby 3.2 and 3.3
- **Coverage**: Code coverage reporting (via Codecov)
- **Code Review**: At least one maintainer approval

### Release Process

- Releases are automated via GitHub Actions
- Version bumps trigger automatic gem publishing to RubyGems
- See `docs/releasing.md` for details

## Documentation

Always keep documentation up-to-date when making changes:

- **README.md**: Quick start and overview
- **CHANGELOG.md**: Version history and changes
- **docs/**: Comprehensive documentation
  - `installation.md` - Installation guide
  - `configuration.md` - Configuration options
  - `resources.md` - Resource DSL reference
  - `fields.md` - Field types and options
  - `actions.md` - Custom actions
  - `portals.md` - Portal system
  - `theming.md` - UI customization
  - `development.md` - Development setup
  - `troubleshooting.md` - Common issues

## Key Principles

1. **Minimal Host App Requirements**: The engine should work with minimal configuration in host apps
2. **Declarative Configuration**: Prefer DSL over imperative code
3. **Extensibility**: Allow host apps to override and extend behavior
4. **Hotwire-First**: Use Turbo and Stimulus for interactivity
5. **Performance**: Keep pages fast, use pagination for large datasets
6. **Security**: Require authentication configuration, sanitize inputs
7. **Accessibility**: Follow basic accessibility guidelines in views

## Security Considerations

1. **Authentication**: Always require `config.authenticate` to be set
2. **Authorization**: Resource-level authorization via `authorize` blocks
3. **Input Validation**: Validate and sanitize all user inputs
4. **SQL Injection**: Use parameterized queries, avoid raw SQL
5. **XSS Prevention**: Escape output in views (Rails default)
6. **Secrets**: Never commit secrets or credentials

## Troubleshooting

Common issues and solutions are documented in `docs/troubleshooting.md`. When adding new features or fixing bugs, update this document if the issue is likely to be encountered by others.

## Additional Resources

- Repository: https://github.com/techwright-lab/admin_suite
- Changelog: https://github.com/techwright-lab/admin_suite/blob/main/CHANGELOG.md
- License: MIT
