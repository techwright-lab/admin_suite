# AdminSuite

A mountable Rails engine that provides a **resource-based admin UI** (CRUD + search/filter/sort),
a **portal/dashboard system**, and a built-in **Markdown docs viewer**.

This engine is currently extracted from the Gleania app and is intended to be reused
across other products.

## Features

- **Portals**: group resources by portal + section, optional per-portal dashboards
- **Resources DSL**: index (columns/filters/stats), form fields, show panels/associations, actions
- **Docs viewer**: renders `*.md` from your host app filesystem at `/docs`
- **Admin MCP**: four read tools derived from resource definitions, under operator authentication and explicit authorization
- **UI**: baseline CSS + engine Tailwind build; host overrides optional

## Documentation

[Read the documentation](https://techwright-lab.github.io/admin_suite/) —
[Installation](https://techwright-lab.github.io/admin_suite/installation/),
[Resources](https://techwright-lab.github.io/admin_suite/resources/), and
[Admin MCP](https://techwright-lab.github.io/admin_suite/mcp/).

Canonical AdminSuite documentation lives in the TechWright vault at
`../_vault/products/admin_suite/docs/`. This repo intentionally has no root
`docs/` tree or docs symlink. The Jekyll site in `site/` publishes a generated,
allowlisted snapshot. See the [publication guide](https://techwright-lab.github.io/admin_suite/docs-publication/)
or its canonical source, `../_vault/products/admin_suite/docs/docs-publication.md`,
for export, drift checks, local preview, and GitHub Pages setup.

## Architecture check

`bin/archspec check` and `bin/archspec-baseline` enforce engine, namespace, and dummy-app boundaries in `Archspec.rb`. They do not boot Rails. Do not grow `archspec_todo.yml`.

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

Resolve the host user and authorize admin access:

```ruby
# config/initializers/admin_suite.rb
AdminSuite.configure do |config|
  config.auth_strategy = :host_user
  config.auth_options = { resolve: ->(controller) { controller.current_user } }
  config.authorize = ->(actor:, action:, resource:, record:, context:) { actor&.admin? }
end
```

Read more: [Configuration](https://techwright-lab.github.io/admin_suite/configuration/).

Set `config.authorize` to decide *what* an authenticated actor may do:

```ruby
config.authorize = ->(actor:, action:, resource:, record:, context:) {
  # action is :read, :create, :update, :destroy, or :execute
  true
}
```

A `false` or `nil` return is `403` (fail closed). Leaving the hook `nil`
keeps authentication as the only web gate; MCP serves no tools or data. Resources marked `read_only` reject
CRUD, `toggle`, and named execute/bulk actions regardless of this hook.

The MCP endpoint is `<mount>/mcp`. See
[Admin MCP](https://techwright-lab.github.io/admin_suite/mcp/) for setup, tool contracts and migration.

### Add portals (navigation metadata)

```ruby
AdminSuite.configure do |config|
  config.portals = {
    ops: { label: "Ops", icon: "settings", color: :amber, order: 10 },
    ai: { label: "AI", icon: "cpu", color: :cyan, order: 20 }
  }
end
```

Read more: [Portals & dashboards](https://techwright-lab.github.io/admin_suite/portals/).

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

Read more: [Resources](https://techwright-lab.github.io/admin_suite/resources/) and [Fields](https://techwright-lab.github.io/admin_suite/fields/).

### Add docs (optional)

Set `config.docs_path` to an explicit documentation source. TechWright host apps point this at their canonical `_vault/products/<product>/docs/` directory; they do not create repo `docs/` trees.

Then visit:

- `/internal/admin/docs`

Read more: [Docs viewer](https://techwright-lab.github.io/admin_suite/docs-viewer/).

## Contributing

See:

- `CONTRIBUTING.md`
- `../_vault/products/admin_suite/docs/development.md`
- `../_vault/products/admin_suite/docs/releasing.md`
