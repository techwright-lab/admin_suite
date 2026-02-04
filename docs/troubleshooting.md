# Troubleshooting

## “My resources don’t show up in the sidebar”

Checklist:

- Your resource class:
  - is under `Admin::Resources`
  - ends with `Resource` (e.g. `UserResource`)
  - sets both `portal :...` and `section :...`
- The file is located under one of the configured `resource_globs` paths (see [Configuration](configuration.md)).

In development, AdminSuite loads resources on-demand when building navigation. In non-development environments, you should ensure your resource files are loaded at boot (using the globs) and are not excluded by your deployment setup.

## “Constant not found” / Zeitwerk errors for host DSL files

If you store AdminSuite DSL files under `app/admin_suite/**` in the host app, those files are not constant definitions.

AdminSuite ignores `Rails.root/app/admin_suite` in Zeitwerk to prevent eager-load errors. If you still see issues:

- Ensure the DSL folder really is `app/admin_suite` (not a different path)
- Prefer `config/admin_suite/resources/*.rb` and `config/admin_suite/portals/*.rb` for DSL files

## “Docs viewer shows no files”

- Confirm `AdminSuite.config.docs_path` exists
- Ensure files are `*.md`
- Visit `/docs` relative to your mount path (e.g. `/internal/admin/docs`)

## “Tailwind styles are missing in production”

AdminSuite expects `assets:precompile` to run and generate:

- `app/assets/builds/admin_suite_tailwind.css` in your host app

If you don’t run precompile in your deployment pipeline, you can:

- Start running `assets:precompile`, or
- Build the file manually by running:

```bash
bin/rails admin_suite:tailwind:build
```

## “Icons don’t render”

AdminSuite defaults to `lucide-rails`.

If your host app excludes it, set `AdminSuite.config.icon_renderer` to provide icons (see [Theming & assets](theming.md)).

