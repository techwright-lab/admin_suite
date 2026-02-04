# Docs viewer

AdminSuite includes a built-in docs viewer at:

- `/docs` (relative to the mount path)

It renders Markdown (`.md`) files from a folder on your host app filesystem.

## Quick start

1. Create `docs/` in your host app:

```bash
mkdir -p docs
```

2. Add a markdown file:

```md
<!-- docs/getting_started.md -->
# Getting started

Hello from AdminSuite docs.
```

3. Visit:

- `/internal/admin/docs`

## Configuring the docs root (`config.docs_path`)

By default:

- `AdminSuite.config.docs_path = Rails.root.join("docs")`

You can point it somewhere else:

```ruby
AdminSuite.configure do |config|
  config.docs_path = Rails.root.join("admin_docs")
end
```

Or compute per-request:

```ruby
AdminSuite.configure do |config|
  config.docs_path = ->(_controller) { Rails.root.join("docs") }
end
```

## Sidebar “Docs” link (`config.docs_url`)

If you want a persistent docs link in the AdminSuite sidebar, set:

```ruby
AdminSuite.configure do |config|
  config.docs_url = "/internal/admin/docs"
end
```

This can also point to external docs.

## Organization

Docs are grouped by their first folder name. For example:

- `docs/ops/runbooks.md` → group “Ops”
- `docs/api/authentication.md` → group “API”
- `docs/getting_started.md` → group “Docs”

## Security notes

The docs viewer defends against path traversal:

- Rejects any path containing `..`
- Requires a `.md` extension
- Resolves realpaths and ensures the requested file stays under the docs root

