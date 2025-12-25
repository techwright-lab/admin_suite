# Adding New Resources to the Developer Portal

This guide explains how to add a new model to the Developer Portal admin interface.

## Quick Start

Adding a new resource requires 3 steps:
1. Create a resource definition file
2. Create a controller
3. Add routes

## Step 1: Create Resource Definition

Create a file in `app/admin/resources/` named `{model_name}_resource.rb`:

```ruby
# app/admin/resources/widget_resource.rb
# frozen_string_literal: true

module Admin
  module Resources
    class WidgetResource < Admin::Base::Resource
      # Required: specify the model class
      model ::Widget

      # Required: assign to a portal (:ops, :ai, or :assistant)
      portal :ops

      # Optional: group in sidebar section
      section "Content"

      # Define the index page
      index do
        # Search across these fields (requires 3+ characters)
        searchable :name, :description

        # Default sort field and direction
        sortable default: :created_at, direction: :desc

        # Items per page
        paginate 25

        # Stats cards at the top
        stats do
          stat :total, -> { ::Widget.count }
          stat :active, -> { ::Widget.where(active: true).count }, color: :green
          stat :inactive, -> { ::Widget.where(active: false).count }, color: :red
        end

        # Filter sidebar
        filters do
          filter :status, type: :select, collection: [
            ["All", ""],
            ["Active", "active"],
            ["Inactive", "inactive"]
          ]
          filter :category_id, type: :select, 
                 collection: -> { Category.pluck(:name, :id) },
                 label: "Category"
        end

        # Table columns
        columns do
          column :id
          column :name, sortable: true
          column :status, type: :badge
          column :active, type: :toggle, toggle_field: :active
          column :created_at, ->(w) { w.created_at.strftime("%b %d, %Y") }, 
                 header: "Created", sortable: true
        end
      end

      # Define the form (new/edit)
      form do
        section "Basic Info" do
          field :name, required: true
          field :description, type: :textarea, rows: 4
          field :category_id, type: :searchable_select,
                collection: -> { Category.pluck(:name, :id) },
                placeholder: "Select a category..."
        end

        section "Settings" do
          field :active, type: :toggle, help: "Enable or disable this widget"
          field :config, type: :json, rows: 10
        end
      end

      # Define the show page
      show do
        # Sidebar (right column - smaller)
        sidebar do
          panel "Details" do
            field :id
            field :status
            field :active
            field :created_at
            field :updated_at
          end
        end

        # Main content (left column - larger)
        main do
          panel "Information" do
            field :name
            field :description
            field :config, type: :json
          end

          # Show associations
          panel "Related Items", association: :items, display: :table do
            column :id
            column :name
            column :status
          end
        end
      end

      # Define member actions (appear on show page)
      actions do
        action :enable, method: :post, 
               if: ->(r) { !r.active },
               confirm: "Enable this widget?"
        action :disable, method: :post, color: :danger,
               if: ->(r) { r.active },
               confirm: "Disable this widget?"
        action :merge, type: :modal  # Opens merge form
      end
    end
  end
end
```

## Step 2: Create Controller

Create a controller in the appropriate portal namespace:

```ruby
# app/controllers/internal/developer/ops/widgets_controller.rb
# frozen_string_literal: true

module Internal
  module Developer
    module Ops
      class WidgetsController < Internal::Developer::ResourcesController
        # Custom actions (if needed)
        def enable
          @resource.update(active: true)
          redirect_to resource_url(@resource), notice: "Widget enabled."
        end

        def disable
          @resource.update(active: false)
          redirect_to resource_url(@resource), notice: "Widget disabled."
        end

        def merge
          @merge_candidates = resource_class.where.not(id: @resource.id).order(:name).limit(100)
        end

        def merge_into
          target = resource_class.find(params[:target_id])
          result = Widget.merge_widgets(@resource, target)
          
          if result[:success]
            redirect_to resource_url(target), notice: "Merged successfully. #{result[:message]}"
          else
            redirect_to merge_internal_developer_ops_widget_path(@resource), alert: result[:error]
          end
        end

        private

        def current_portal
          :ops
        end

        def resource_config
          Admin::Resources::WidgetResource
        end
      end
    end
  end
end
```

## Step 3: Add Routes

Add routes in `config/routes/developer.rb` under the appropriate portal namespace:

```ruby
namespace :ops do
  # ... other resources ...
  
  resources :widgets, concerns: [:toggleable, :mergeable] do
    member do
      post :enable
      post :disable
    end
  end
end
```

### Available Route Concerns

| Concern | Actions Added |
|---------|---------------|
| `:toggleable` | `enable`, `disable`, `toggle` (POST) |
| `:mergeable` | `merge` (GET), `merge_into` (POST) |
| `:exportable` | `export` (GET) |
| `:publishable` | `publish`, `unpublish` (POST) |
| `:status_manageable` | `open`, `close`, `resolve` (POST) |

## DSL Reference

### Index Configuration

```ruby
index do
  searchable :field1, :field2          # Fields to search
  sortable default: :name, direction: :asc  # Default sort
  paginate 25                          # Items per page
  
  stats do
    stat :name, -> { Model.count }, color: :green
  end
  
  filters do
    filter :name, type: :text
    filter :status, type: :select, collection: [...]
    filter :active, type: :toggle
    filter :date, type: :date
  end
  
  columns do
    column :name                       # Simple column
    column :name, sortable: true       # Sortable column
    column :name, header: "Display"    # Custom header
    column :custom, ->(r) { r.foo }    # Lambda for value
    column :status, type: :badge       # Badge display
    column :active, type: :toggle, toggle_field: :active  # Toggle switch
  end
end
```

### Form Configuration

```ruby
form do
  section "Section Name" do
    field :name                        # Text field (default)
    field :name, required: true        # Required field
    field :name, type: :textarea, rows: 6
    field :name, type: :select, collection: [["Label", "value"]]
    field :name, type: :searchable_select, 
          collection: -> { Model.pluck(:name, :id) }
    field :name, type: :toggle
    field :name, type: :markdown
    field :name, type: :json
    field :name, type: :file, accept: "image/*"
    field :name, type: :tags, collection: -> { Tag.pluck(:name) }, creatable: true
  end
  
  row cols: 2 do  # Two columns side by side
    field :field1
    field :field2
  end
end
```

### Show Configuration

```ruby
show do
  sidebar do
    panel "Title" do
      field :name
      field :status, type: :badge
    end
  end
  
  main do
    panel "Title" do
      field :description
      field :config, type: :json
    end
    
    # Association display options
    panel "Items", association: :items, display: :list, limit: 10
    panel "Items", association: :items, display: :table do
      column :id
      column :name
    end
    panel "Items", association: :items, display: :cards
  end
end
```

### Action Configuration

```ruby
actions do
  action :name, 
         method: :post,              # HTTP method
         label: "Display Label",     # Button text
         icon: "icon-name",          # Optional icon
         color: :danger,             # :default, :danger
         type: :modal,               # :button (default), :modal
         confirm: "Are you sure?",   # Confirmation dialog
         if: ->(r) { r.condition },  # Show condition
         unless: ->(r) { r.other }   # Hide condition
end
```

## Best Practices

1. **Use the correct portal**: Place resources in the appropriate portal based on their domain
2. **Add meaningful stats**: Include stats that provide actionable insights
3. **Enable sorting**: Add `sortable: true` to commonly sorted columns
4. **Use searchable selects**: For foreign key fields with many options
5. **Add confirmations**: Use `confirm:` for destructive actions
6. **Show associations**: Display related records on show pages
7. **Add model merge methods**: For mergeable resources, implement a `merge_*` class method

## Troubleshooting

### Resource not showing in sidebar
- Ensure `portal` and `section` are defined in the resource
- Check that routes are added to `config/routes/developer.rb`

### Controller action not found
- Define `resource_config` method returning the resource class
- Define `current_portal` method returning the portal symbol

### Form field not rendering
- Check field type is supported
- For `searchable_select`, ensure collection is a Proc or Array

### Search not working
- Requires 3+ characters to trigger
- Ensure `searchable` fields are database columns

