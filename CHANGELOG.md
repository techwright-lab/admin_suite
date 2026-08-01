# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Index rows are now clickable end to end via the already-existing (but
  previously unwired) `ClickActionsController`: clicking anywhere on a row
  other than an interactive element (link, button, form input) navigates to
  the record's show page.
- A 25/50/100 per-page selector in the index's existing filter form,
  clamped server-side to a maximum of 100 regardless of what the
  `per_page` query param requests, falling back to the resource's
  `paginate(n)` value when the param is absent or invalid (non-numeric,
  zero, negative, or array-shaped).
- `column :name, align: :right` (also `:center`, `:left`) DSL option,
  emitting the matching Tailwind alignment class on the `<td>`.
- The index's `<thead>` is now `sticky top-0`, and its scroll wrapper is
  now bounded (`max-h-[70vh] overflow-y-auto`, alongside the existing
  `overflow-x-auto`) so the header actually pins while scrolling a long
  page of results instead of scrolling away with it.

### Changed
- **Host-visible:** resources declaring `paginate(n)` now render that many
  rows per page instead of Pagy's own default of 20 — see the Fixed entry
  below. Operators may see different row counts and pagination boundaries
  than they're used to.
- `column.css_class` (populated by the DSL's `class:` option) is now
  applied to the rendered `<td>`. Previously accepted but never read.
- A column value that is `nil` now renders as `—`, matching every other
  surface in the gem, instead of a blank cell. Applies to both plain
  scalar columns and `belongs_to`-shaped association columns.

### Fixed
- `paginate_collection` called `pagy(scope, items: n)`. Pagy's vars key
  is `limit:`, not `items:` — `items:` silently did nothing, so **every
  resource's `paginate(n)` DSL value has been ignored since the gem's
  first commit**, with every index quietly paginating at Pagy's own
  default of 20 regardless of what was declared. This is a long-standing
  latent bug, not a regression introduced by this release; declared page
  sizes now take effect.

## [0.4.0] - 2026-08-01

### Added
- `AdminSuite::Renderer` base class for show-panel renderers, with shared
  primitives (`json_block`, `code_block`, `key_value_list`, `data_table`,
  `badge`, `empty_state`). Host renderers live in `app/admin/renderers/*.rb`
  as `Admin::Renderers::<Key>Renderer` and are autoloaded from a panel's
  `render: :<key>` option.
- Built-in renderers `:json`, `:key_value`, `:table_from` and `:code`, usable
  from any resource with no host code. See
  `../_vault/products/admin_suite/docs/renderers.md`.
- Explicit renderer registration via `AdminSuite::RendererRegistry.register`.
- Sections are first-class: `AdminSuite.portal :ops do section(:runs) { label "Runs"; order 10 } end`.
  Undeclared sections keep the previous humanized-label, alphabetical-order behavior.
- `BigDecimal` show-value formatting.

### Changed (BREAKING)
- `config.portals = {}` now suppresses the gem's built-in default portals.
  Previously `{}` was `blank?` and the defaults re-applied, giving hosts that
  cleared portals four phantom nav entries.
- Removed `config.tailwind_cdn` (no consumers) and `ColumnDefinition`'s
  `render:` option (never read).
- Actions returning a persisted record now derive a redirect for any action,
  not only one named `:duplicate`.
- Association-panel pagination now renders through the same partial as index
  pagination, which has richer markup than the old association-only
  implementation — a visual change for hosts using paginated association
  panels.
- Unknown form field types now render a plain text field via a registry
  default, the same fallback `:text`/`:string` already used, instead of a
  separate legacy fallback path. Recognized types are unaffected.

### Deprecated
- `config.custom_renderers[:key] = ->(record, view) {}` procs — migrate to
  `AdminSuite::Renderer` subclasses. Procs keep working in 0.4.x and take
  precedence over a renderer class registered under the same key, so hosts
  can migrate one panel at a time. See
  `../_vault/products/admin_suite/docs/renderers.md`. Now warns once per
  key per process when a legacy proc is used — previously deprecated on
  paper only, with no runtime signal.
- The built-in `:prompt_template_preview`, `:messages_preview`,
  `:tool_args_preview` and `:turn_messages_preview` renderers. They warn once
  per key per process and are **removed in 0.5.0**.
- `Resource.exportable(*formats)` — a no-op that warns once per resource
  class, naming the class, and is **removed in 0.5.0**. It was write-only
  in every prior release (never had a reader, never drove any export
  behavior); calling it is now harmless instead of raising `NoMethodError`
  at resource-definition time.

### Fixed
- A host `Admin::Renderers::<Key>Renderer` class (or an explicit
  `RendererRegistry.register` call) could be silently shadowed by the
  gem's own built-in/deprecated-Gleania registrations under the same key,
  defeating the deprecation advice that recommends defining exactly such a
  class. `RendererRegistry` now separates gem defaults
  (`register_default`) from explicit registrations (`register`);
  `render_custom_section`'s precedence is: legacy `config.custom_renderers`
  proc, explicit registration, host renderer class, gem default.
- A bare `rescue ActiveRecord::RecordNotFound` in `ResourcesController#set_resource`
  raised `NameError` while handling the real exception in a host without
  ActiveRecord loaded, masking it (same failure class as the AASM fix
  below). Three `object.is_a?(ActiveRecord::Base)` call sites in
  `BaseHelper` had the same problem in its plain-crash form (not masking,
  just a 500) and are now guarded by a shared `active_record_base?`
  predicate.
- The engine no longer force-includes
  `Internal::Developer::CustomRenderersHelper` into every view. Verified
  non-breaking: a host's `helper :all` (the Rails default) still supplies
  it.
- EasyMDE is vendored instead of loaded from a CDN (strict-CSP and
  air-gapped hosts).
- A bare `AASM::InvalidTransition` rescue raised `NameError` during exception
  handling in hosts without AASM installed, masking the original error.
- Index stat cards no longer emit dynamic Tailwind classes the content
  scanner cannot see.
- Index and association-panel pagination were two divergent implementations;
  now one partial.
- Definition files (resources/actions/portals/dashboards) that raise during
  load now surface the error immediately in development and test, instead of
  being silently retried — the old `rescue NameError; retry` could infinite-loop
  in production when a require legitimately failed.

## [0.3.1] - 2026-08-01

### Fixed

- Chart panels now give percentage-height bars a definite-height container, preserve full axis labels, and keep small nonzero values visible.

## [0.3.0] - 2026-07-31

### Changed (BREAKING)
- AdminSuite now **fails closed**: with no authentication configured, every
  engine request responds 403. Configure `config.auth_strategy = :http_basic`
  (or a custom strategy, or the legacy `config.authenticate` lambda). For
  development/test only, `config.allow_unauthenticated = true` restores open
  access (ignored in production).
- `read_only` resources now also reject the built-in `toggle` endpoint;
  undeclared `execute_action` and `bulk_action` names respond 404 via a
  dedicated bulk-action lookup. Declared member and bulk actions remain
  allowed on `read_only` resources by design.
- `execute_action` with an unknown action name now responds 404 instead of
  redirecting with an "Action not found." alert.

### Added
- Pluggable auth strategies: `AdminSuite::Auth.register`, built-in
  `:http_basic` (ENV or `config.auth_options` credentials, constant-time
  comparison, blank credentials deny).
- `config.authorize` is now enforced for every resource action with the
  contract `->(actor:, action:, resource:, record:, controller:)`,
  action ∈ :read/:create/:update/:destroy/:execute.
- `config.skip_host_before_actions` (default `[:require_authentication]`)
  replaces the hardcoded host-filter skip.

### Fixed
- `config.current_actor` is now consulted at most once per request
  (was invoked repeatedly by views; side-effecting lambdas fired multiple times).
- Requests for resource names with no registered resource definition now
  respond 404 instead of resolving host model classes directly (closes an
  authorization bypass).

## [0.2.9] - 2026-07-14

### Added

- Read-only resource support, server-side filter defaults, and filtered-scope statistics.

## [0.2.8] - 2026-03-23

### Added

- **Dependent searchable select** field type (`:dependent_select`) — cascading dropdowns where a child field's options filter by the selected parent value. Uses `parent_field:` option and `[label, value, group]` collection triples.
- **Stimulus entry point** (`admin_suite_application.js`) — automatically imports and registers all 12 AdminSuite Stimulus controllers on `window.Stimulus`.
- `parent_field` attribute on `FieldDefinition` for linking dependent fields.

### Fixed

- **Stimulus controllers not loading** — engine controllers were pinned via importmap but never imported. Added explicit entry point in layout via `<script type="module">`.
- **Searchable select change propagation** — `applyOption()` now dispatches a `change` event on the hidden input, enabling dependent field chaining.

### Security

- New `dependent_searchable_select_controller.js` uses safe DOM construction (`createElement`/`textContent`/`appendChild`) instead of `innerHTML` template literals.

## [0.2.6] - 2026-02-21

### Added

- Automated GitHub Release creation in the publish workflow, with release notes extracted from `CHANGELOG.md`.
- When no `CHANGELOG.md` entry exists for the current version, release notes are now primarily auto-generated from commits since the previous tag, with the plain "Release vX.Y.Z" string used only as a final fallback when no commit-generated notes are available.

## [0.1.0] - 2026-02-04

### Added

- Initial extraction of the AdminSuite Rails engine.
- Resource/portal DSL, docs viewer, and theming primitives.
- Isolated gem test suite with a dummy Rails app.
