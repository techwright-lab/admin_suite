# Saved Jobs, Fit Score, Strengths/Domains

## Goals
- **Saved Jobs**: Users can save job leads from either an `Opportunity` or a pasted `url` and manage them in a Saved Jobs list.
- **Conversion**: Saved jobs can be converted into an `InterviewApplication` using existing flows.
- **Fit Score**: Persist a per-user fit score for each `Opportunity`, `SavedJob`, and `InterviewApplication`.
- **Strengths/Domains**: Persist resume-derived strengths/domains, and show a merged “Strengths” view that combines **resume-derived** + **feedback-derived** strengths.

## Data model
### `SavedJob`
New table/model `SavedJob` (user-owned bookmark).
- **Associations**:
  - `belongs_to :user`
  - `belongs_to :opportunity, optional: true`
- **Fields**:
  - `url` (nullable)
  - optional caches: `company_name`, `job_role_title`, `title`, `notes`
  - `converted_at` (nullable)
- **Constraints**:
  - exactly one of `opportunity_id` or `url` must be present
  - unique `(user_id, opportunity_id)` where opportunity_id is not null
  - unique `(user_id, url)` where url is not null

### `FitAssessment` (polymorphic)
New table/model for persisted fit computations.
- **Associations**:
  - `belongs_to :user`
  - `belongs_to :fittable, polymorphic: true` (`Opportunity`, `SavedJob`, `InterviewApplication`)
- **Fields**:
  - `score` (0..100)
  - `status` enum: `pending/computed/failed`
  - `computed_at`
  - `algorithm_version`
  - `inputs_digest`
  - `breakdown` jsonb
- **Constraint**: unique `(user_id, fittable_type, fittable_id)`

### Persist resume-derived strengths/domains
Add columns to `user_resumes`:
- `strengths` jsonb default `[]`
- `domains` jsonb default `[]`

These are already returned by resume AI extraction (`Resumes::AiSkillExtractorService`) and currently passed through `Resumes::AnalysisService`.

## Saved Jobs workflow + UI
### Entry points
- **Opportunities stack**: Add “Save” button in [`app/views/opportunities/_card.html.erb`](app/views/opportunities/_card.html.erb).
- **Saved Jobs page**: Add paste-URL form and list.

### Routes/controllers
- Add `resources :saved_jobs, only: [:index, :create, :destroy]`.
- Add `POST /saved_jobs/:id/convert`:
  - URL-based: reuse `InterviewApplicationsController#quick_apply` / `QuickApplyFromUrlService`.
  - Opportunity-based: reuse `Opportunities::CreateApplicationService`.

### Stack behavior
Exclude saved opportunities from `OpportunitiesController#index` ([`app/controllers/opportunities_controller.rb`](app/controllers/opportunities_controller.rb)) so a saved card disappears from the actionable stack.

### Sidebar
Add a “Saved” link + badge in [`app/views/shared/_sidebar.html.erb`](app/views/shared/_sidebar.html.erb).

## Fit score computation (MVP)
### Inputs
- **User skills**: `UserSkill` aggregated profile (`app/models/user_skill.rb`).
- **Job text**:
  - Prefer `job_listing` fields (`description`, `requirements`, `responsibilities`, `custom_sections`) when present.
  - Otherwise fall back to `Opportunity` fields (`job_role_title`, `key_details`, `email_snippet`) or SavedJob caches.

### Algorithm (deterministic first pass)
- Identify job “skill mentions” by scanning job text for known `SkillTag` names.
- Compute weighted overlap using `UserSkill.aggregated_level`.
- Normalize to 0..100.
- Store matched/missing skills in `FitAssessment.breakdown`.

### Services/jobs
- `Fit::ComputeAssessmentService` (upsert `FitAssessment` for `(user, fittable)`).
- `ComputeFitAssessmentJob` for async.

### Triggers
- After resume analysis completes (end of `Resumes::AnalysisService#run` or `AnalyzeResumeJob`): enqueue recompute for the user’s actionable opportunities, saved jobs, and active applications.
- After a job listing scrape completes successfully (`ScrapeJobListingJob`): enqueue recompute for dependent items.

## Strengths & domains in the skill profile
### Persistence
- In [`app/services/resumes/analysis_service.rb`](app/services/resumes/analysis_service.rb), persist `strengths/domains` onto the analyzed `UserResume`.

### Aggregation + display
- **Per-resume**: show strengths/domains on resume show page.
- **Aggregated resume strengths/domains**: compute counts across analyzed resumes.
- **Feedback strengths**: reuse `ProfileInsightsService#top_strengths` (`app/services/profile_insights_service.rb`).
- **Merged Strengths list (single list, tagged)**:
  - Merge resume strengths + feedback strengths by normalized name.
  - Display each item with `sources: [resume, feedback]` and count(s).

Add to:
- skill profile partial: [`app/views/user_resumes/_skill_profile.html.erb`](app/views/user_resumes/_skill_profile.html.erb)
- skills dashboard: [`app/controllers/skills_controller.rb`](app/controllers/skills_controller.rb) and [`app/views/skills/index.html.erb`](app/views/skills/index.html.erb)

## Implementation checklist
- Add migrations for `saved_jobs`, `fit_assessments`, and `user_resumes.strengths/domains`.
- Add models + associations + validations.
- Add Saved Jobs controller/routes/views and Opportunities “Save” button.
- Implement fit computation service + background job + triggers.
- Persist and render strengths/domains; merge strengths with feedback insights.

