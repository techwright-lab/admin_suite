# Theming & assets

AdminSuite is designed to work in two modes:

1. **Engine-build mode (default)**: AdminSuite builds and ships its own Tailwind CSS into your host app at `assets:precompile` time.
2. **Host-themed mode (optional)**: your host app includes a stylesheet after AdminSuite for branding/overrides.

## Theme colors (`config.theme`)

AdminSuite uses CSS variables scoped to `body.admin-suite`.

```ruby
AdminSuite.configure do |config|
  config.theme = { primary: :emerald, secondary: :cyan }
end
```

### Allowed values

- **Named colors**: symbols/strings like `:indigo`, `:emerald`, `:cyan`, `:amber`, `:violet`, `:slate`, etc.
- **Hex**: `"#4f46e5"` (uses that exact color as primary/secondary in key places)

The theme primarily drives:

- Primary links/buttons (`--admin-suite-primary`, `--admin-suite-primary-hover`)
- Sidebar gradient (`--admin-suite-sidebar-from/via/to`)

## Host stylesheet (`config.host_stylesheet`)

If your host app already has Tailwind (or you want to override the engine UI), you can include an additional stylesheet after AdminSuite in the engine layout:

```ruby
AdminSuite.configure do |config|
  config.host_stylesheet = :app
end
```

This calls `stylesheet_link_tag :app` after `admin_suite.css` and `admin_suite_tailwind.css`.

## Tailwind build

AdminSuite writes an engine stylesheet into your host app during `assets:precompile`:

- Input: `AdminSuite::Engine.root/app/assets/tailwind/admin_suite.css`
- Output: `Rails.root/app/assets/builds/admin_suite_tailwind.css`

In development, the engine also makes a best-effort to create the output file if it’s missing, so the UI stays usable.

## Icons

AdminSuite uses lucide icons by default via `lucide-rails`.

If you need a different icon provider:

```ruby
AdminSuite.configure do |config|
  config.icon_renderer = ->(name, view, **opts) do
    # return HTML-safe SVG (string or ActiveSupport::SafeBuffer)
    view.content_tag(:span, name, class: opts[:class])
  end
end
```

