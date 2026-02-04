# Installation

## Requirements

- Ruby **3.2+**
- Rails **8.0+**

AdminSuite is a mountable engine. You mount it under a path in your host app’s `config/routes.rb`.

## Add the gem

In your host app `Gemfile`:

```ruby
gem "admin_suite"
```

Then:

```bash
bundle install
```

## Install into your app

Run the install generator (creates an initializer and mounts the engine):

```bash
bin/rails g admin_suite:install
```

To mount at a custom path:

```bash
bin/rails g admin_suite:install --mount-path=/internal/admin
```

This will:

- Create `config/initializers/admin_suite.rb`
- Add a route like `mount AdminSuite::Engine => "/internal/admin"`

## First run checklist

- **Auth**: set `config.authenticate` so only permitted users can access AdminSuite.
- **Actor**: set `config.current_actor` if you want actions/auditing to know “who did it”.
- **Resources**: add at least one resource definition file (see [Resources](resources.md)).
- **Portals**: set up portal metadata and dashboards (see [Portals](portals.md)).

## Assets (CSS/JS)

AdminSuite ships with:

- A small baseline stylesheet (`admin_suite.css`)
- A compiled Tailwind stylesheet (`admin_suite_tailwind.css`) that is built into the host app at asset precompile time
- Engine-provided Stimulus controllers via importmap

### CSS build behavior

When your app runs `assets:precompile`, AdminSuite automatically runs:

- `admin_suite:tailwind:build` → writes `app/assets/builds/admin_suite_tailwind.css` in your **host app**

So in production you typically just need to ensure your deployment runs `assets:precompile` as usual.

### Host stylesheet overrides (optional)

If your app already uses Tailwind (or you want custom branding), you can include your app stylesheet after AdminSuite:

- Set `config.host_stylesheet` (see [Theming & assets](theming.md))

## Routes and URLs

Assuming you mounted at `/internal/admin`:

- `/internal/admin` → AdminSuite dashboard
- `/internal/admin/docs` → docs viewer (optional)
- `/internal/admin/:portal` → portal dashboard (optional)
- `/internal/admin/:portal/:resource_name` → resource index

