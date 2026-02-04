# Resources

Resources are defined using `Admin::Base::Resource`.

AdminSuite loads resource definition files from `AdminSuite.config.resource_globs`
(defaults include `config/admin_suite/resources/*.rb` and `app/admin/resources/*.rb`).

## Create a resource

A resource is a Ruby class under `Admin::Resources` ending in `Resource`.

Example:

```ruby
# config/admin_suite/resources/user.rb
module Admin
  module Resources
    class UserResource < Admin::Base::Resource
      model ::User
      portal :ops
      section :accounts

      nav label: "Users", icon: "users", order: 10

      index do
        searchable :email, :name
        sortable :created_at, :email, default: :created_at, direction: :desc
        paginate 50

        columns do
          column :id
          column :email
          column :created_at
          column :admin, type: :toggle, toggle_field: :admin, header: "Admin?"
          column :status, type: :label, label_color: ->(u) { u.active? ? :emerald : :slate }, label_size: :sm
        end

        filters do
          filter :search, type: :text, placeholder: "Search users..."
          filter :status, type: :select, options: [["Active", "active"], ["Inactive", "inactive"]]
        end

        stats do
          stat :total, -> { User.count }, color: :slate
          stat :new_24h, -> { User.where("created_at > ?", 24.hours.ago).count }, color: :emerald
        end
      end

      form do
        section "Basics", description: "Core account fields" do
          field :email, type: :email, required: true
          field :name, required: true
        end

        row cols: 2 do
          field :admin, type: :toggle, help: "Grants access to internal tools."
          field :status, type: :select, collection: [["Active", "active"], ["Inactive", "inactive"]]
        end
      end

      show do
        main do
          panel :details, title: "User details", fields: %i[email name status created_at]
          panel :activity, title: "Activity", render: :custom_activity_timeline
        end

        sidebar do
          panel :summary, title: "Summary", fields: %i[id admin]
        end
      end

      actions do
        action :reset_password, label: "Reset password", icon: "key", confirm: "Send reset email?"
      end
    end
  end
end
```

## Core DSL

### Model

```ruby
model ::User
```

### Navigation placement

```ruby
portal :ops
section :accounts
```

These determine:

- URL: `/:portal/:resource_name`
- Sidebar placement: portal group → section group → resource link

### Navigation metadata

```ruby
nav label: "Users", icon: "users", order: 10
```

Also available as convenience setters:

```ruby
label "Users"
icon "users"
order 10
```

## Index DSL (`index do ... end`)

### Search

```ruby
searchable :name, :email
```

Search uses `ILIKE` across the configured fields.

### Sort

```ruby
sortable :created_at, :email, default: :created_at, direction: :desc
```

### Pagination

```ruby
paginate 25
```

### Columns

```ruby
columns do
  column :email
  column :job_listings, ->(u) { u.job_listings.count }
end
```

`column` options:

- `header:` string (defaults to a humanized name)
- `class:` css class for the cell
- `render:` custom render key (advanced)
- `type:` `:toggle` or `:label` (special rendering)
- `toggle_field:` field to flip when `type: :toggle`
- `label_color:` color for `type: :label` (Symbol or Proc)
- `label_size:` `:sm`/`:md` (or Proc)
- `sortable:` boolean (reserved for future per-column sorting UI)

### Filters

```ruby
filters do
  filter :status, type: :select, options: [["Active", "active"], ["Inactive", "inactive"]]
end
```

Filter options:

- `type:` (default `:text`)
- `label:`
- `placeholder:`
- `options:` / `collection:` (for select-like UI)
- `field:` which model field to filter on (defaults to the filter name)
- `apply:` Proc that receives the scope (advanced)

### Stats

```ruby
stats do
  stat :total, -> { User.count }, color: :slate
end
```

## Form DSL (`form do ... end`)

```ruby
form do
  field :name, required: true
  field :website, type: :url
end
```

See [Fields](fields.md) for supported types and options.

AdminSuite also supports basic layout helpers in forms:

- `section "Title" do ... end`
- `row cols: 2 do ... end`

## Show DSL (`show do ... end`)

Show is section-based. Sections can live in the main column or sidebar.

```ruby
show do
  main do
    panel :details, title: "Details", fields: %i[name email]
    panel :related, title: "Projects", association: :projects, display: :table, columns: %i[id name status], paginate: true
  end

  sidebar do
    panel :meta, title: "Meta", fields: %i[id created_at updated_at]
  end
end
```

Panel options:

- `title:` (defaults to a humanized name)
- `fields:` array of field names to display
- `render:` custom renderer key (see `custom_renderers` in [Configuration](configuration.md))
- `association:` association name to render (`has_many`, `belongs_to`, etc.)
- `display:` `:list` (default), `:table`, or `:cards` for associations
- `columns:` columns for association `:table` display
- `link_to:` helper method name to build links for association items (optional)
- `paginate:` boolean, enables pagination within the association section
- `per_page:` items per page for association pagination
- `limit:` max items (if not paginating)
- `collapsible:` / `collapsed:` (reserved for future UI toggles)

## Actions DSL (`actions do ... end`)

```ruby
actions do
  action :reindex, label: "Reindex", method: :post, confirm: "Reindex this record?"
end
```

See [Actions](actions.md) for how actions execute and how to define handlers.

