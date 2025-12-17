---
name: AdminPanelContentActionsAndTaxonomy
overview: Add admin actions (disable/enable/delete/merge) to core content resources and upgrade admin filters with consistent Tailwind styling + searchable autocomplete inputs (with create-new). Replace free-form category strings with managed Category records to reduce duplication and enable dedup workflows.
todos:
  - id: soft-disable-core-models
    content: Add disabled_at + enabled/disabled scopes for Company/JobRole/JobListing/SkillTag; update autocompletes to exclude disabled by default.
    status: completed
  - id: admin-actions-disable-delete
    content: Add disable/enable routes + controller actions and expose actions in admin index tables; guard destructive deletes.
    status: completed
  - id: filter-sidebar-styling
    content: Update admin/shared/_filter_sidebar.html.erb to use .form-input/.form-select and support date/checkbox consistently.
    status: completed
  - id: filter-autocomplete
    content: Extend filter sidebar to render autocomplete filters (company/job_role/category/skill_tag) using shared/autocomplete.
    status: completed
  - id: categories-model
    content: Introduce Category model + migrations; migrate JobRole.category and SkillTag.category into Category records and FK references.
    status: completed
  - id: merge-dedup-foundation
    content: Add merge services + simple admin UI for Companies/JobRoles/SkillTags/Categories to support dedup workflows.
    status: pending
---

## Goals

- Add **Disable/Enable** and **Delete** actions for content resources in Admin: **Companies**, **Job Roles**, **Job Listings**, **Skill Tags**.
- Improve **admin filter sidebar** inputs so they are consistently styled (reuse existing `.form-input`, `.form-select`, etc.).
- Add **searchable inputs** in admin filters for **Company**, **Job Role**, **Tags**, and **Categories** with the ability to **create new**.
- Introduce a **deduplication foundation** (merge workflows + managed categories) to cope with scraped duplicates.

## Key constraints / findings

- Deleting **Company** / **JobRole** is currently dangerous due to cascading associations:
- `Company` has `has_many :job_listings, dependent: :destroy`.
- `JobRole` has `has_many :job_listings, dependent: :destroy`.
- So “Delete” must be gated or replaced by safe “Disable” as the default.
- Admin filter sidebar currently renders plain `<input>/<select>` with minimal styling:
- See [`app/views/admin/shared/_filter_sidebar.html.erb`](app/views/admin/shared/_filter_sidebar.html.erb).
- There is already a reusable, styled autocomplete component and Stimulus controller that support **search + auto-create**:
- [`app/views/shared/_autocomplete.html.erb`](app/views/shared/_autocomplete.html.erb)
- [`app/javascript/controllers/autocomplete_controller.js`](app/javascript/controllers/autocomplete_controller.js)

## Implementation plan

### 1) Add a consistent “disable/enable” mechanism (soft-disable)

- Add `disabled_at:datetime` to:
- `Company`, `JobRole`, `JobListing`, `SkillTag`
- Add shared concerns/scopes:
- `scope :enabled, -> { where(disabled_at: nil) }`
- `scope :disabled, -> { where.not(disabled_at: nil) }`
- `def disabled?` and `def disable! / enable!`
- Update existing autocomplete endpoints to only return enabled records by default:
- [`app/controllers/companies_controller.rb`](app/controllers/companies_controller.rb)
- [`app/controllers/job_roles_controller.rb`](app/controllers/job_roles_controller.rb)

### 2) Add “Disable/Enable/Delete” actions in admin UI

- Update Admin tables to include actions beyond View/Edit:
- [`app/views/admin/companies/index.html.erb`](app/views/admin/companies/index.html.erb)
- [`app/views/admin/job_roles/index.html.erb`](app/views/admin/job_roles/index.html.erb)
- [`app/views/admin/job_listings/index.html.erb`](app/views/admin/job_listings/index.html.erb)
- [`app/views/admin/skill_tags/index.html.erb`](app/views/admin/skill_tags/index.html.erb)
- Add member routes + controller actions:
- `POST /admin/<resource>/:id/disable`
- `POST /admin/<resource>/:id/enable`
- Keep `DELETE` for actual destroy but **guard it** (see below).
- Guard “Delete” to prevent accidental cascades:
- For `Company` and `JobRole`, refuse delete if it would destroy job listings (or require explicit “force delete” behind an extra confirm).
- For `JobListing`/`SkillTag`, allow delete but show strong confirm.

### 3) Make admin filters look good (styled inputs)

- Update [`app/views/admin/shared/_filter_sidebar.html.erb`](app/views/admin/shared/_filter_sidebar.html.erb) to use existing global styles:
- `class="form-input"` for text/number/search
- `class="form-select"` for select
- Add a `:date` type (uses `form-input`)
- Add a `:checkbox` type (styled to match)

### 4) Add searchable + create-new filters (company/job role/tags/categories)

- Extend the admin filter sidebar to support `type: :autocomplete`:
- Renders the shared component [`app/views/shared/_autocomplete.html.erb`](app/views/shared/_autocomplete.html.erb) inside the filter sidebar `form_with`.
- Use GET params like `company_id`, `job_role_id`, `category_id`, `skill_tag_id`.
- Wire it into key admin indexes:
- `Admin::JobListingsController#index` already supports `company_id`; add `job_role_id` and `category_id` if relevant.
- `Admin::InterviewApplicationsController#index` already supports `company_id` and `job_role_id`; add a `skill_tag_id` filter (single-select initially).
- Keep existing `search` text filter as a fallback.
- Add new autocomplete + create endpoints for `SkillTag` and `Category`:
- `GET /skill_tags/autocomplete`
- `POST /skill_tags (JSON)` already exists in admin; add public JSON create similar to companies/job roles OR create a dedicated internal endpoint for admin filters.
- `GET /categories/autocomplete`, `POST /categories (JSON)`.

### 5) Replace “category strings” with managed Categories (dedupe foundation)

- Introduce `Category` model:
- `name` (unique, normalized), `kind` (enum: `job_role`, `skill_tag`), `disabled_at`.
- Migrate:
- Backfill categories from existing `JobRole.category` and `SkillTag.category` strings.
- Add `job_roles.category_id` + `skill_tags.category_id` foreign keys.
- Keep the old string columns temporarily (optional) but stop using them in new UI.
- Update admin forms:
- Job roles and skill tags edit/new should use category autocomplete (create-new) instead of free-text category.

### 6) Add merge/dedup tools (minimal but extensible)

- Add admin “Merge” flows for:
- Companies, Job Roles, Skill Tags, Categories
- Approach:
- New service objects (transactional) that re-point associations from `source` to `target`, then disable or delete source.
- Example outcomes:
- Merge company: move `job_listings.company_id`, `interview_applications.company_id`, user targeting links, etc.
- Merge job role: move `job_listings.job_role_id`, `interview_applications.job_role_id`, targeting links.
- Merge skill tag: use existing `SkillTag.merge_skills` for associations.
- Merge category: move `job_roles.category_id` or `skill_tags.category_id`.
- Add simple admin UI: “Merge…” button on show pages opening a small form with an autocomplete to pick a target.

## Files likely to change

- Styling / filter UX:
- [`app/views/admin/shared/_filter_sidebar.html.erb`](app/views/admin/shared/_filter_sidebar.html.erb)
- Possibly new filter types + reuse [`app/views/shared/_autocomplete.html.erb`](app/views/shared/_autocomplete.html.erb)
- Admin resources:
- [`app/views/admin/job_listings/index.html.erb`](app/views/admin/job_listings/index.html.erb)
- [`app/views/admin/companies/index.html.erb`](app/views/admin/companies/index.html.erb)
- [`app/views/admin/job_roles/index.html.erb`](app/views/admin/job_roles/index.html.erb)
- [`app/views/admin/skill_tags/index.html.erb`](app/views/admin/skill_tags/index.html.erb)
- Corresponding `Admin::*Controller` files for enable/disable/merge
- Autocomplete endpoints:
- [`app/controllers/companies_controller.rb`](app/controllers/companies_controller.rb)
- [`app/controllers/job_roles_controller.rb`](app/controllers/job_roles_controller.rb)
- New `CategoriesController` (autocomplete + JSON create)
- New `SkillTagsController` autocomplete + JSON create (or scoped endpoints)
- Database:
- Migrations for `disabled_at` + `Category` model + foreign keys/backfill
- Routes:
- [`config/routes.rb`](config/routes.rb)

## Rollout / safety

- Default admin action becomes **Disable** (safe) rather than “hard delete”.
- “Delete” remains available but blocked if it would cascade into job listings (company/job role) unless explicitly forced.
- Autocomplete only returns enabled records to reduce noisy duplicates.

## Test plan

- Add request specs for:
- enable/disable endpoints
- category backfill + uniqueness
- filtering by company/job_role/category/tag
- merge services (at least one happy-path + one validation/guard failure)

## Notes

- This plan starts tags filtering as **single skill tag** filter in admin lists (fastest). We can iterate to multi-tag chip picker as a follow-up once the Category + Disable/Merge foundation is in place.