# Portals & dashboards

AdminSuite navigation is organized by **portal** and **section**:

- A **portal** is the top-level grouping (e.g. `:ops`, `:ai`)
- A **section** is a grouping within a portal (e.g. `:billing`, `:users`)
- A **resource** belongs to exactly one portal + section via the resource DSL

You can configure portals in two complementary ways:

1. **Portal metadata** via `AdminSuite.config.portals` (label/icon/color/order)
2. **Portal DSL** via `AdminSuite.portal(:key) { ... }` (metadata + dashboard layout)

## Portal metadata (`config.portals`)

```ruby
AdminSuite.configure do |config|
  config.portals = {
    ops: { label: "Ops", icon: "settings", color: :amber, order: 10 },
    ai: { label: "AI", icon: "cpu", color: :cyan, order: 20 }
  }
end
```

### Portal fields

- `label` (String): display label
- `icon` (String/Symbol): lucide icon name (e.g. `"settings"`)
- `color` (Symbol/String): used for accents (`:amber`, `:emerald`, `:cyan`, `:violet`, `:slate`)
- `order` (Integer): sort order in the root dashboard and sidebar
- `description` (String, optional): shown on the root dashboard cards when present

## Portal DSL (`AdminSuite.portal`)

Portal DSL files are loaded from `AdminSuite.config.portal_globs` (defaults include
`config/admin_suite/portals/*.rb`, `app/admin/portals/*.rb`, `app/admin_suite/portals/*.rb`).

Example file:

```ruby
# config/admin_suite/portals/ops.rb
AdminSuite.portal :ops do
  label "Ops Portal"
  icon "settings"
  color :amber
  order 10
  description "Operational tools and internal resources."

  dashboard do
    row do
      stat_panel "New users (24h)", -> { User.where("created_at > ?", 24.hours.ago).count }, color: :emerald, span: 3
      stat_panel "Failed jobs", -> { SolidQueue::FailedExecution.count }, color: :red, span: 3
    end

    row do
      recent_panel "Recent signups", scope: -> { User.order(created_at: :desc).limit(5) }, span: 6
      table_panel "Queue summary",
        rows: -> { SolidQueue::Job.order(created_at: :desc).limit(10) },
        columns: %i[id class_name created_at],
        span: 6
    end
  end
end
```

## Dashboard DSL

The dashboard DSL is available inside `portal.dashboard do ... end`.

- `dashboard` contains `row { ... }`
- each `row` contains one or more `panel(...)` calls

### Panel helpers

These are convenience helpers that all create a `panel` under the hood:

- `stat_panel(title, value=nil, span: nil, **options, &block)`
- `health_panel(title, status: nil, metrics: nil, span: nil, **options, &block)`
- `chart_panel(title, data: nil, span: nil, **options, &block)`
- `cards_panel(title, resources: nil, span: nil, **options, &block)`
- `recent_panel(title, scope: nil, link: nil, span: nil, **options, &block)`
- `table_panel(title, rows: nil, columns: nil, span: nil, **options, &block)`

### `span`

`span` controls width in a 12-column grid. Typical values: `3`, `4`, `6`, `12`.

## Portal pages

Once mounted, portal pages are served at:

- `/:portal` (relative to the mount path)

Example:

- `/internal/admin/ops`
- `/internal/admin/ai`

