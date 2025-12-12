# Admin UI Design System

This document describes the standardized design system for building admin panel views and controllers. The system provides reusable components, concerns, and helpers to ensure consistency across all admin pages.

## Table of Contents

1. [Overview](#overview)
2. [Controller Concerns](#controller-concerns)
3. [View Partials](#view-partials)
4. [Helper Methods](#helper-methods)
5. [Usage Examples](#usage-examples)
6. [Design Patterns](#design-patterns)

## Overview

The admin design system consists of:

- **Controller Concerns**: Reusable logic for pagination, filtering, and stats
- **View Partials**: Reusable UI components for common patterns
- **Helper Methods**: Utility functions for generating HTML
- **Design Tokens**: Consistent styling using Tailwind CSS

All admin pages follow a consistent structure:
- Page header with title and breadcrumbs
- Stats grid (optional)
- Filter sidebar (optional)
- Data table or content area
- Pagination (when applicable)

## Controller Concerns

### Paginatable

Provides standardized pagination logic.

```ruby
class Admin::UsersController < Admin::BaseController
  include Admin::Concerns::Paginatable

  PER_PAGE = 30

  def index
    @users = paginate(filtered_users)
    # Sets @page, @total_count, @total_pages automatically
  end
end
```

**Methods:**
- `paginate(collection, per_page: nil)` - Paginates a collection and sets instance variables

### Filterable

Provides standardized filter parameter handling.

```ruby
class Admin::UsersController < Admin::BaseController
  include Admin::Concerns::Filterable

  def index
    @users = paginate(filtered_users)
    @filters = filter_params
  end

  private

  def filtered_users
    users = User.all
    users = users.where(status: filter_params[:status]) if filter_params[:status].present?
    users
  end

  def filter_params
    params.permit(:status, :search, :sort)
  end
end
```

**Methods:**
- `filter_params` - Returns permitted filter parameters (override in your controller)

### StatsCalculator

Provides a standardized way to calculate statistics.

```ruby
class Admin::UsersController < Admin::BaseController
  include Admin::Concerns::StatsCalculator

  def index
    @stats = calculate_stats
  end

  private

  def calculate_stats
    {
      total: User.count,
      active: User.active.count,
      inactive: User.inactive.count
    }
  end
end
```

**Methods:**
- `calculate_stats` - Returns a hash of statistics (override in your controller)

## View Partials

### Page Header

Displays page title, description, breadcrumbs, and action buttons.

```erb
<%= render "admin/shared/page_header",
    title: "Users",
    description: "Manage users and view their Gmail sync status" %>

<!-- With breadcrumbs -->
<%= render "admin/shared/page_header",
    title: @user.display_name,
    description: @user.email_address,
    breadcrumbs: [
      { label: "Users", path: admin_users_path },
      { label: @user.display_name }
    ] %>

<!-- With actions -->
<%= render "admin/shared/page_header",
    title: "Users",
    actions: link_to("New User", new_admin_user_path, class: "btn-primary") %>
```

**Parameters:**
- `title` - Page title (required)
- `description` - Page description (optional)
- `breadcrumbs` - Array of breadcrumb items (optional)
- `actions` - HTML for action buttons (optional)

### Stats Grid

Displays a grid of statistic cards.

```erb
<%= render "admin/shared/stats_grid",
    stats: {
      total: 150,
      active: 120,
      inactive: 30
    } %>

<!-- With custom colors -->
<%= render "admin/shared/stats_grid",
    stats: @stats,
    colors: {
      total: "text-slate-900 dark:text-white",
      active: "text-green-600 dark:text-green-400",
      inactive: "text-red-600 dark:text-red-400"
    },
    columns: 4 %>
```

**Parameters:**
- `stats` - Hash of statistics (required)
- `colors` - Hash mapping stat keys to color classes (optional)
- `columns` - Number of columns (optional, auto-detected)

### Filter Sidebar

Displays a filter form in a sidebar.

```erb
<%= render "admin/shared/filter_sidebar",
    url: admin_users_path,
    filters: [
      {
        type: :text,
        name: :search,
        label: "Search",
        placeholder: "Email or name...",
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
```

**Filter Types:**
- `:text` / `:search` - Text input
- `:select` - Dropdown select
- `:number` - Number input

**Parameters:**
- `url` - Form submission URL (defaults to current path)
- `filters` - Array of filter definitions (required)
- `width` - Sidebar width class (optional, defaults to "lg:w-56")

### Data Table

Displays a data table with consistent styling.

```erb
<%= render "admin/shared/data_table",
    collection: @users,
    columns: [
      { 
        header: "User",
        content: ->(user) { user.display_name }
      },
      { 
        header: "Email",
        content: ->(user) { user.email_address }
      },
      { 
        header: "Status",
        content: ->(user) { render "admin/shared/status_badge", status: user.status }
      },
      { 
        header: "Actions",
        content: ->(user) { link_to "View", admin_user_path(user) }
      }
    ],
    empty_message: "No users found" %>
```

**Parameters:**
- `collection` - Array or ActiveRecord relation (required)
- `columns` - Array of column definitions (required)
- `empty_message` - Message to show when collection is empty (optional)
- `empty_colspan` - Number of columns for empty message (optional)

**Column Definition:**
- `header` or `label` - Column header text
- `content` - Proc, Symbol, or String for cell content
- `class` - Additional CSS classes for the column

### Pagination

Displays pagination controls.

```erb
<%= render "admin/shared/pagination",
    page: @page,
    total_pages: @total_pages,
    total_count: @total_count,
    per_page: Admin::UsersController::PER_PAGE %>
```

**Parameters:**
- `page` - Current page number (required)
- `total_pages` - Total number of pages (required)
- `total_count` - Total number of items (required)
- `per_page` - Items per page (required)

### Status Badge

Displays a status badge with consistent styling.

```erb
<%= render "admin/shared/status_badge", status: "active" %>

<!-- With custom colors -->
<%= render "admin/shared/status_badge",
    status: "pending",
    custom_colors: { pending: "bg-yellow-100 text-yellow-800" } %>
```

**Default Status Colors:**
- `active` - Green
- `inactive` - Gray
- `pending` - Amber
- `completed` - Green
- `failed` - Red
- `closed` - Gray
- `draft` - Amber

### Action Bar

Displays action buttons for show/edit pages.

```erb
<%= render "admin/shared/action_bar", actions: [
  { 
    label: "Edit",
    path: edit_admin_user_path(@user),
    style: :primary
  },
  { 
    label: "Delete",
    path: admin_user_path(@user),
    method: :delete,
    style: :danger,
    confirm: "Are you sure?"
  },
  {
    label: "View Original",
    path: @user.url,
    target: "_blank",
    style: :secondary
  }
] %>
```

**Action Styles:**
- `:primary` - Amber button (default)
- `:secondary` - Gray button
- `:danger` - Red button
- `:outline` - Outlined button

### Info Card

Displays key-value information in a card.

```erb
<%= render "admin/shared/info_card",
    title: "User Details",
    data: {
      "Name" => @user.name,
      "Email" => @user.email_address,
      "Role" => @user.role,
      "Created" => @user.created_at.strftime("%B %d, %Y")
    } %>
```

**Parameters:**
- `title` - Card title (optional)
- `data` - Hash of label-value pairs (required)
- `class_name` - Additional CSS classes (optional)

## Helper Methods

### admin_breadcrumbs

Generates breadcrumb navigation.

```erb
<%= admin_breadcrumbs([
  { label: "Users", path: admin_users_path },
  { label: @user.display_name }
]) %>
```

### admin_status_badge

Generates a status badge.

```erb
<%= admin_status_badge("active") %>
<%= admin_status_badge("pending", custom_colors: { pending: "bg-yellow-100" }) %>
```

### admin_stat_card

Generates a stat card.

```erb
<%= admin_stat_card("Total Users", 150, color: "text-slate-900") %>
```

## Usage Examples

### Complete Index Page Example

**Controller:**

```ruby
class Admin::UsersController < Admin::BaseController
  include Admin::Concerns::Paginatable
  include Admin::Concerns::Filterable
  include Admin::Concerns::StatsCalculator

  PER_PAGE = 30

  def index
    @users = paginate(filtered_users)
    @stats = calculate_stats
    @filters = filter_params
  end

  private

  def filtered_users
    users = User.includes(:connected_accounts)
    users = users.where(status: filter_params[:status]) if filter_params[:status].present?
    users = users.where("email_address ILIKE ?", "%#{filter_params[:search]}%") if filter_params[:search].present?
    users.order(created_at: :desc)
  end

  def calculate_stats
    {
      total: User.count,
      active: User.active.count,
      inactive: User.inactive.count
    }
  end

  def filter_params
    params.permit(:status, :search, :sort)
  end
end
```

**View:**

```erb
<% content_for :title, "Users - Admin" %>

<div class="px-4 sm:px-6 lg:px-8">
  <%= render "admin/shared/page_header",
      title: "Users",
      description: "Manage users and view their Gmail sync status" %>

  <%= render "admin/shared/stats_grid", stats: @stats %>

  <div class="flex flex-col lg:flex-row gap-6">
    <%= render "admin/shared/filter_sidebar",
        url: admin_users_path,
        filters: [
          {
            type: :text,
            name: :search,
            label: "Search",
            placeholder: "Email or name...",
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
          collection: @users,
          columns: [
            { 
              header: "User",
              content: ->(user) { user.display_name }
            },
            { 
              header: "Email",
              content: ->(user) { user.email_address }
            },
            { 
              header: "Status",
              content: ->(user) { render "admin/shared/status_badge", status: user.status }
            },
            { 
              header: "Actions",
              content: ->(user) { link_to "View", admin_user_path(user), class: "text-amber-600 hover:text-amber-800" }
            }
          ],
          empty_message: "No users found" %>

      <%= render "admin/shared/pagination",
          page: @page,
          total_pages: @total_pages,
          total_count: @total_count,
          per_page: Admin::UsersController::PER_PAGE %>
    </div>
  </div>
</div>
```

### Complete Show Page Example

**View:**

```erb
<% content_for :title, "#{@user.display_name} - Admin" %>

<div class="px-4 sm:px-6 lg:px-8">
  <%= render "admin/shared/page_header",
      title: @user.display_name,
      description: @user.email_address,
      breadcrumbs: [
        { label: "Users", path: admin_users_path },
        { label: @user.display_name }
      ],
      actions: link_to("Edit", edit_admin_user_path(@user), class: "btn-primary") %>

  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <div class="lg:col-span-2 space-y-6">
      <!-- Main content sections -->
    </div>

    <div class="space-y-6">
      <%= render "admin/shared/info_card",
          title: "User Details",
          data: {
            "Name" => @user.name,
            "Email" => @user.email_address,
            "Role" => @user.role,
            "Created" => @user.created_at.strftime("%B %d, %Y")
          } %>
    </div>
  </div>
</div>
```

## Design Patterns

### Standard Page Structure

1. **Container**: `<div class="px-4 sm:px-6 lg:px-8">`
2. **Page Header**: Use `_page_header` partial
3. **Stats Grid** (optional): Use `_stats_grid` partial
4. **Content Area**: 
   - For index pages: Filter sidebar + Data table + Pagination
   - For show pages: Main content + Sidebar with info cards
5. **Action Bar** (for show/edit pages): Use `_action_bar` partial

### Color Scheme

- **Primary**: Amber (`amber-500`, `amber-600`)
- **Success**: Green (`green-600`, `green-400`)
- **Warning**: Amber (`amber-600`, `amber-400`)
- **Danger**: Red (`red-600`, `red-400`)
- **Neutral**: Slate (`slate-600`, `slate-400`)

### Spacing

- **Page padding**: `px-4 sm:px-6 lg:px-8`
- **Section spacing**: `mb-6` or `space-y-6`
- **Card padding**: `p-4` or `p-6`
- **Gap between elements**: `gap-4` or `gap-6`

### Typography

- **Page title**: `text-2xl font-bold`
- **Section title**: `text-lg font-semibold`
- **Card title**: `text-sm font-semibold`
- **Body text**: `text-sm`
- **Helper text**: `text-xs`

## Best Practices

1. **Always use partials** for common UI patterns instead of duplicating code
2. **Include concerns** in controllers to standardize pagination, filtering, and stats
3. **Use consistent naming** for instance variables (`@page`, `@total_pages`, `@filters`, `@stats`)
4. **Follow the standard page structure** for consistency
5. **Use helper methods** for simple HTML generation
6. **Document custom filters** and stats in controller comments
7. **Test pagination** with edge cases (empty collections, single page, etc.)

## Migration Guide

To migrate existing admin pages to use the design system:

1. **Update Controller**:
   - Include relevant concerns (`Paginatable`, `Filterable`, `StatsCalculator`)
   - Replace manual pagination with `paginate()` method
   - Extract filter logic to `filtered_*` method
   - Extract stats to `calculate_stats` method

2. **Update View**:
   - Replace page header HTML with `_page_header` partial
   - Replace stats grid with `_stats_grid` partial
   - Replace filter sidebar with `_filter_sidebar` partial
   - Replace table HTML with `_data_table` partial
   - Replace pagination HTML with `_pagination` partial
   - Replace status badges with `_status_badge` partial

3. **Test**:
   - Verify pagination works correctly
   - Verify filters work correctly
   - Verify stats display correctly
   - Verify responsive design works
