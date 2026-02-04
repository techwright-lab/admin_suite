# AdminSuite

A mountable Rails engine that provides a **resource-based admin UI** (CRUD + search/filter/sort),
a **portal/dashboard system**, and a built-in **Markdown docs viewer**.

This engine is currently extracted from the Gleania app and is intended to be reused
across other products.

## Features

- **Portals**: group resources by portal + section, optional per-portal dashboards
- **Resources DSL**: index (columns/filters/stats), form fields, show panels/associations, actions
- **Docs viewer**: renders `*.md` from your host app filesystem at `/docs`
- **UI**: baseline CSS + engine Tailwind build; host overrides optional

## Documentation

Start here:

- `docs/README.md` (index)

Read more:

- `docs/installation.md`
- `docs/configuration.md`
- `docs/portals.md`
- `docs/resources.md`
- `docs/fields.md`
- `docs/actions.md`
- `docs/theming.md`
- `docs/docs_viewer.md`
- `docs/troubleshooting.md`

## Quickstart

Add the gem:

```ruby
# Gemfile
gem "admin_suite"
```

Install and generate the initializer + mount:

```bash
bundle install
bin/rails g admin_suite:install
```

By default, the engine mounts at `/internal/admin`. You can customize it:

```bash
bin/rails g admin_suite:install --mount-path=/internal/admin
```

### Secure it (recommended)

Set `config.authenticate` so only authorized users can access AdminSuite:

```ruby
# config/initializers/admin_suite.rb
AdminSuite.configure do |config|
  config.authenticate = ->(controller) do
    user = controller.respond_to?(:current_user) ? controller.current_user : nil
    controller.head(:forbidden) unless user&.admin?
  end
end
```

Read more: `docs/configuration.md`

### Add portals (navigation metadata)

```ruby
AdminSuite.configure do |config|
  config.portals = {
    ops: { label: "Ops", icon: "settings", color: :amber, order: 10 },
    ai: { label: "AI", icon: "cpu", color: :cyan, order: 20 }
  }
end
```

Read more: `docs/portals.md`

### Add a resource

Place resource definitions under one of the default globs (recommended):

- `config/admin_suite/resources/*.rb`

Example:

```ruby
# config/admin_suite/resources/user.rb
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
    end
  end
end
```

Read more: `docs/resources.md` and `docs/fields.md`

### Add docs (optional)

Create markdown files in your host app:

- `docs/*.md` (or set `config.docs_path`)

Then visit:

- `/internal/admin/docs`

Read more: `docs/docs_viewer.md`

## Contributing

See:

- `CONTRIBUTING.md`
- `docs/development.md`
- `docs/releasing.md`

