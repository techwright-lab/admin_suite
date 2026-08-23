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

Canonical AdminSuite documentation lives in the TechWright vault at
`../_vault/products/admin_suite/docs/`. This repo intentionally has no root
`docs/` tree or docs symlink.

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

Read more: `../_vault/products/admin_suite/docs/configuration.md`

Set `config.authorize` to decide *what* an authenticated actor may do:

```ruby
config.authorize = ->(actor:, action:, resource:, record:, controller:) {
  # action is :read, :create, :update, :destroy, or :execute
  true
}
```

A `false` or `nil` return is `403` (fail closed). Leaving the hook `nil`
keeps authentication as the only gate. Resources marked `read_only` reject
CRUD, `toggle`, and named execute/bulk actions regardless of this hook.

### Add portals (navigation metadata)

```ruby
AdminSuite.configure do |config|
  config.portals = {
    ops: { label: "Ops", icon: "settings", color: :amber, order: 10 },
    ai: { label: "AI", icon: "cpu", color: :cyan, order: 20 }
  }
end
```

Read more: `../_vault/products/admin_suite/docs/portals.md`

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

Read more: `../_vault/products/admin_suite/docs/resources.md` and `../_vault/products/admin_suite/docs/fields.md`

### Add docs (optional)

Set `config.docs_path` to an explicit documentation source. TechWright host apps point this at their canonical `_vault/products/<product>/docs/` directory; they do not create repo `docs/` trees.

Then visit:

- `/internal/admin/docs`

Read more: `../_vault/products/admin_suite/docs/docs_viewer.md`

## Contributing

See:

- `CONTRIBUTING.md`
- `../_vault/products/admin_suite/docs/development.md`
- `../_vault/products/admin_suite/docs/releasing.md`

