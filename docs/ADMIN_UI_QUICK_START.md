# Admin UI Design System - Quick Start Guide

This is a quick reference guide for using the admin design system. For detailed documentation, see [ADMIN_UI_DESIGN_SYSTEM.md](./ADMIN_UI_DESIGN_SYSTEM.md).

## Quick Setup

### 1. Update Your Controller

```ruby
class Admin::YourController < Admin::BaseController
  include Admin::Concerns::Paginatable
  include Admin::Concerns::Filterable
  include Admin::Concerns::StatsCalculator

  PER_PAGE = 30  # Adjust as needed

  def index
    @items = paginate(filtered_items)
    @stats = calculate_stats
    @filters = filter_params
  end

  private

  def filtered_items
    items = YourModel.all
    items = items.where(status: filter_params[:status]) if filter_params[:status].present?
    items = items.where("name ILIKE ?", "%#{filter_params[:search]}%") if filter_params[:search].present?
    items.order(created_at: :desc)
  end

  def calculate_stats
    {
      total: YourModel.count,
      active: YourModel.active.count
    }
  end

  def filter_params
    params.permit(:status, :search, :sort)
  end
end
```

### 2. Update Your Index View

```erb
<% content_for :title, "Your Items - Admin" %>

<div class="px-4 sm:px-6 lg:px-8">
  <!-- Header -->
  <%= render "admin/shared/page_header",
      title: "Your Items",
      description: "Manage your items" %>

  <!-- Stats -->
  <%= render "admin/shared/stats_grid", stats: @stats %>

  <!-- Filters and Table -->
  <div class="flex flex-col lg:flex-row gap-6">
    <%= render "admin/shared/filter_sidebar",
        url: admin_your_items_path,
        filters: [
          {
            type: :text,
            name: :search,
            label: "Search",
            placeholder: "Search...",
            value: @filters[:search]
          },
          {
            type: :select,
            name: :status,
            label: "Status",
            options: [["All", ""], ["Active", "active"], ["Inactive", "inactive"]],
            value: @filters[:status]
          }
        ] %>

    <div class="flex-1 min-w-0">
      <%= render "admin/shared/data_table",
          collection: @items,
          columns: [
            { header: "Name", content: ->(item) { item.name } },
            { header: "Status", content: ->(item) { render "admin/shared/status_badge", status: item.status } },
            { header: "Actions", content: ->(item) { link_to "View", admin_your_item_path(item) } }
          ],
          empty_message: "No items found" %>

      <%= render "admin/shared/pagination",
          page: @page,
          total_pages: @total_pages,
          total_count: @total_count,
          per_page: Admin::YourController::PER_PAGE %>
    </div>
  </div>
</div>
```

### 3. Update Your Show View

```erb
<% content_for :title, "#{@item.name} - Admin" %>

<div class="px-4 sm:px-6 lg:px-8">
  <!-- Header with Breadcrumbs -->
  <%= render "admin/shared/page_header",
      title: @item.name,
      description: @item.description,
      breadcrumbs: [
        { label: "Items", path: admin_your_items_path },
        { label: @item.name }
      ],
      actions: link_to("Edit", edit_admin_your_item_path(@item), class: "btn-primary") %>

  <!-- Action Bar -->
  <%= render "admin/shared/action_bar", actions: [
    { label: "Edit", path: edit_admin_your_item_path(@item), style: :primary },
    { label: "Delete", path: admin_your_item_path(@item), method: :delete, style: :danger, confirm: "Are you sure?" }
  ] %>

  <!-- Content -->
  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <div class="lg:col-span-2">
      <!-- Main content -->
    </div>

    <div>
      <%= render "admin/shared/info_card",
          title: "Details",
          data: {
            "Name" => @item.name,
            "Status" => @item.status,
            "Created" => @item.created_at.strftime("%B %d, %Y")
          } %>
    </div>
  </div>
</div>
```

## Available Components

### Partials (in `app/views/admin/shared/`)

- `_page_header` - Page title, description, breadcrumbs, actions
- `_stats_grid` - Grid of statistic cards
- `_filter_sidebar` - Filter form sidebar
- `_data_table` - Data table with consistent styling
- `_pagination` - Pagination controls
- `_status_badge` - Status badge with colors
- `_action_bar` - Action buttons for show/edit pages
- `_info_card` - Key-value information card

### Concerns (in `app/controllers/admin/concerns/`)

- `Paginatable` - Pagination logic
- `Filterable` - Filter parameter handling
- `StatsCalculator` - Statistics calculation

### Helpers (in `app/helpers/admin_helper.rb`)

- `admin_breadcrumbs(items)` - Generate breadcrumbs
- `admin_status_badge(status, custom_colors: {})` - Generate status badge
- `admin_stat_card(label, value, color:)` - Generate stat card

## Common Patterns

### Filter Sidebar with Multiple Filters

```erb
<%= render "admin/shared/filter_sidebar",
    url: admin_items_path,
    filters: [
      { type: :text, name: :search, label: "Search", value: @filters[:search] },
      { type: :select, name: :status, label: "Status", 
        options: [["All", ""], ["Active", "active"]], value: @filters[:status] },
      { type: :select, name: :sort, label: "Sort By",
        options: [["Recent", "recent"], ["Name", "name"]], value: @filters[:sort] }
    ] %>
```

### Data Table with Custom Columns

```erb
<%= render "admin/shared/data_table",
    collection: @items,
    columns: [
      { 
        header: "Name",
        content: ->(item) { link_to item.name, admin_item_path(item) }
      },
      { 
        header: "Status",
        content: ->(item) { render "admin/shared/status_badge", status: item.status }
      },
      { 
        header: "Actions",
        content: ->(item) do
          link_to("View", admin_item_path(item), class: "text-amber-600") +
          " | " +
          link_to("Edit", edit_admin_item_path(item), class: "text-slate-600")
        end
      }
    ] %>
```

### Status Badge with Custom Colors

```erb
<%= render "admin/shared/status_badge",
    status: "custom_status",
    custom_colors: { 
      custom_status: "bg-purple-100 text-purple-800 dark:bg-purple-900/20 dark:text-purple-400"
    } %>
```

## Migration Checklist

When migrating an existing admin page:

- [ ] Include relevant concerns in controller (`Paginatable`, `Filterable`, `StatsCalculator`)
- [ ] Replace manual pagination with `paginate()` method
- [ ] Extract filter logic to `filtered_*` method
- [ ] Extract stats to `calculate_stats` method
- [ ] Replace page header HTML with `_page_header` partial
- [ ] Replace stats grid with `_stats_grid` partial
- [ ] Replace filter sidebar with `_filter_sidebar` partial
- [ ] Replace table HTML with `_data_table` partial
- [ ] Replace pagination HTML with `_pagination` partial
- [ ] Replace status badges with `_status_badge` partial
- [ ] Test pagination, filters, and responsive design

## Need Help?

- See [ADMIN_UI_DESIGN_SYSTEM.md](./ADMIN_UI_DESIGN_SYSTEM.md) for detailed documentation
- Check `app/views/admin/shared/_component_reference.html.erb` for visual examples
- Look at existing admin controllers/views for real-world examples
