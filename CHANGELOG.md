# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2026-08-01

### Added
- **Charts.** `chart_panel` now renders a real Chart.js chart (Chart.js
  4.5.1, vendored at `app/assets/vendor/chart.umd.min.js` — no gem
  dependency, no CDN, works air-gapped/under a strict CSP), loaded only on
  pages that actually render a chart with data. New `type:` option —
  `:bar` (default), `:line`, `:area` (a Chart.js line chart with
  `fill: true`), or `:doughnut`; an unrecognized value falls back to
  `:bar` and logs a warning rather than raising, regardless of the input's
  type (Symbol, String, Integer, Boolean, ...). New `height:` option (see
  Changed below for the new default). The existing CSS bar chart remains
  the no-JS degraded state — nothing is hidden until Chart.js has actually
  built the real chart. See
  `../_vault/products/admin_suite/docs/charts.md`.
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
  `overflow-x-auto`) so the header actually pins **within that scroll
  region** while scrolling a long page of results — not to the browser
  viewport — instead of scrolling away with the page.
- `index do includes :company, :line_items end` — eager-loads the named
  associations on the index's filtered/sorted/searched scope, before
  pagination. Skips silently on a scope that doesn't support `#includes`;
  logs and degrades (unoptimized, still renders) if `#includes` itself
  raises (e.g. a bad association name). See
  `../_vault/products/admin_suite/docs/resources.md`.
- A gem-provided JSON search endpoint, `GET <mount>/:portal/:resource/search?q=`,
  for `searchable_select` — hosts no longer need to hand-build one. Enforces
  authentication and `config.authorize` (`action: :read`), only searches the
  resource's declared `searchable` fields, hard-caps at 25 results, and
  returns `[]` (never the whole table) for a blank/missing `q`. New field
  option `resource:` resolves a `searchable_select` field's search URL to
  this endpoint automatically; a String `collection:` still overrides it
  unconditionally. See `../_vault/products/admin_suite/docs/fields.md`.
- `hide_blank: true` on show `fields:` panels (sidebar or main column) hides
  a field's row entirely instead of rendering a label with an empty value.
  Deliberately stricter than `.blank?`: only `nil`/`""`/`[]`/`{}` are
  hidden — whitespace-only strings, `false`, and `0`/`0.0` are kept, since
  none of those are "no data," and `false`/`0` are today's real rendered
  values for a lot of fields. See
  `../_vault/products/admin_suite/docs/resources.md`.

### Changed
- **Host-visible:** `belongs_to`-shaped values now render as links to the
  associated record's own admin show page — in both index columns
  (previously a raw `#<Company:0x...>` inspect string) and association
  tables (previously plain text). Falls back to plain text (never a raw
  inspect string, never a 500) when no resource is registered for the
  associated class, the record is unpersisted, or its display title
  raises.
- **Host-visible:** the chart panel's default height changed from a 64px
  strip to **192px**. 64px was enough for a sparkline-style bar row but not
  a real chart with axes/labels; both the degraded bars and the live canvas
  read the same height value, so there's no shift between the two, but
  every existing dashboard's chart panels are now taller unless `height:`
  is set explicitly. `chart_panel`'s markup for hosts overriding
  `config.partials[:panel_chart]` has also changed shape (new Stimulus
  mount + data attributes) — see the charts doc.
- **Host-visible:** resources declaring `paginate(n)` now render that many
  rows per page instead of Pagy's own default of 20 — see the Fixed entry
  below. Operators may see different row counts and pagination boundaries
  than they're used to.
- `column.css_class` (populated by the DSL's `class:` option) is now
  applied to the rendered `<td>`. Previously accepted but never read.
- A column value that is `nil` now renders as `—`, matching every other
  surface in the gem, instead of a blank cell. Applies to both plain
  scalar columns and `belongs_to`-shaped association columns.
- **Host-visible:** the `pagy` dependency range is now `>= 9.0, < 10`
  (previously `>= 6.0, < 11.0`). `paginate_collection` calls `pagy(scope,
  limit:)` (see the Fixed entry above) — `limit:` is Pagy 9.x's vars key,
  silently ignored on Pagy 6-8, and Pagy 10 reworked the backend API
  again. A host resolving Pagy 6-8 for another reason will now get a real
  bundler resolution conflict at `bundle update` instead of quietly
  reintroducing the "paginate(n) ignored, 20 rows forever" bug this
  release fixes.
- `turbo-rails` is now an explicit gem dependency. The engine has always
  hard-depended on it (`turbo_frame_tag` in the resource views;
  `format.turbo_stream`/`turbo_stream.replace` in the `toggle` action) —
  this declares what was already true, it does not add a new
  requirement.

### Fixed
- `paginate_collection` called `pagy(scope, items: n)`. Pagy's vars key
  is `limit:`, not `items:` — `items:` silently did nothing, so **every
  resource's `paginate(n)` DSL value has been ignored since the gem's
  first commit**, with every index quietly paginating at Pagy's own
  default of 20 regardless of what was declared. This is a long-standing
  latent bug, not a regression introduced by this release; declared page
  sizes now take effect.
- A chart panel's `data:` proc raising, returning junk rows (non-Hash
  entries mixed into the array), or returning rows with a non-numeric
  `value` (Boolean, Hash, Array, nil, non-numeric String) all previously
  500'd the dashboard. All three now degrade instead: a raising proc logs
  and shows "No chart data."; junk rows are dropped; junk values render as
  a zero-height bar/slice. String-keyed data rows (e.g. from a JSONB
  column) are also now tolerated the same way `data_table` already
  handles them — previously they rendered blank/zero bars silently rather
  than the real value.
- A chart panel's `height:` option 500'd the dashboard for any value that
  survives `presence` but doesn't respond to `#to_i` (`true`, a Symbol, a
  non-empty Array or Hash — e.g. `height: :tall` or `height: [200]`). Now
  totally coerced the same way `data:` row values are, falling back to the
  default 192px for anything that doesn't genuinely parse as a number.
  `color:` had the same gap (pre-existing since 0.4.0): any value without
  `#to_sym` (an Integer, Boolean, ...) 500'd the dashboard instead of
  falling through to the existing unknown-color default (indigo).

### Deprecated
- **Unchanged, reiterated for clarity:** the four Gleania-specific renderer
  keys (`:prompt_template_preview`, `:messages_preview`,
  `:tool_args_preview`, `:turn_messages_preview`) and
  `Resource.exportable(*formats)` remain deprecated (as of 0.4.0) and
  **still work in 0.5.0**. Their removal, originally targeted at 0.5.0, is
  now targeted at **0.6.0**, pending the Gleania and TrustGrowth host
  migrations. The runtime deprecation warnings (and their source comments)
  have been retargeted to say 0.6.0 as part of this release.

## [0.4.0] - 2026-08-01

### Added
- `AdminSuite::Renderer` base class for panel renderers, with shared
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
  per key per process and are **removed in 0.5.0** (removal retargeted to
  0.6.0 — see [0.5.0]).
- `Resource.exportable(*formats)` — a no-op that warns once per resource
  class, naming the class, and is **removed in 0.5.0** (removal retargeted
  to 0.6.0 — see [0.5.0]). It was write-only in every prior release (never
  had a reader, never drove any export behavior); calling it is now
  harmless instead of raising `NoMethodError` at resource-definition time.

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
