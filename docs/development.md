# Development

This page is intended for contributors/maintainers working on the engine itself.

## Setup

From the gem root:

```bash
bundle install
```

## Run tests

```bash
bundle exec rake test
```

## Dummy app

AdminSuite uses a Rails “dummy” app under `test/dummy` for integration tests and to
exercise routing/assets in a host-like environment.

Useful commands (from the gem root):

```bash
cd test/dummy
bin/rails s
```

## Assets / Tailwind

AdminSuite ships:

- `app/assets/admin_suite.css` (baseline CSS)
- `app/assets/tailwind/admin_suite.css` (Tailwind input)

The engine Tailwind build task writes the compiled CSS into the **host app** builds folder:

- Output: `Rails.root/app/assets/builds/admin_suite_tailwind.css`

In a host app, this is run automatically during `assets:precompile`:

```bash
bin/rails admin_suite:tailwind:build
```

When developing inside the engine repo itself, you can run it from the dummy app:

```bash
cd test/dummy
bin/rails admin_suite:tailwind:build
```

## Docs

Engine docs live under:

- `docs/`

The docs viewer feature in the engine reads from the host app by default:

- `Rails.root/docs` (configurable via `AdminSuite.config.docs_path`)

