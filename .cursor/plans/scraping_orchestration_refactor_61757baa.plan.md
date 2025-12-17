---
name: scraping_orchestration_refactor
overview: Refactor the oversized Scraping::OrchestratorService into a focused orchestration namespace with small, test-backed improvements, while keeping Scraping::OrchestratorService as a backwards-compatible wrapper.
todos:
  - id: orchestration-namespace
    content: "Create `Scraping::Orchestration` namespace: Context + Runner + Steps folder skeleton."
    status: pending
  - id: extract-steps
    content: Move orchestrator flow into step objects (DetectJobBoard, FetchHtml, RenderedFallback, NokogiriScrape, SelectorsExtract, ApiExtract, AiExtract, Update/Complete).
    status: pending
  - id: thin-wrapper
    content: Refactor `Scraping::OrchestratorService` into a thin wrapper delegating to `Scraping::Orchestration::Runner`.
    status: pending
  - id: tests-adjust
    content: Update/add tests for runner/steps and delegation; ensure events/logs remain recorded.
    status: pending
---

## Goals

- Reduce complexity in `Scraping::OrchestratorService` by moving the pipeline into a dedicated namespace named **Scraping::Orchestration**.
- Keep existing external entrypoints working (job + retry) by leaving `Scraping::OrchestratorService` as a thin wrapper.
- Preserve the current observability model (ScrapingEvent timeline + HtmlScrapingLog rows), while making it easier to add/modify steps.

## Target structure

- Create `app/services/scraping/orchestration/` with:
- `Scraping::Orchestration::Runner` (top-level pipeline runner)
- `Scraping::Orchestration::Context` (shared state: job_listing, attempt, event_recorder, board detection, html payloads, fetch_mode)
- `Scraping::Orchestration::Steps::*` (small objects, each owning one responsibility)

Example step split (mirrors the current `call` flow in [`/workspaces/gleania/app/services/scraping/orchestrator_service.rb`](file:///workspaces/gleania/app/services/scraping/orchestrator_service.rb)):

- `Steps::DetectJobBoard` (records `job_board_detection`)
- `Steps::FetchHtml` (records `html_fetch`, sets html/cleaned, fetch_mode)
- `Steps::RenderedFallback` (runs heuristic + `RenderedHtmlFetcherService`, records `js_heavy_detected` + `rendered_html_fetch`)
- `Steps::NokogiriScrape` (calls `HtmlScrapingService`, records `nokogiri_scrape`)
- `Steps::SelectorsExtract` (calls `JobBoards::ExtractorFactory`, records `selectors_extraction`, creates selectors HtmlScrapingLog)
- `Steps::ApiExtract` (gated by `Setting.api_population_enabled?`, records `api_extraction` or skipped)
- `Steps::AiExtract` (records `ai_extraction`)
- `Steps::UpdateAndComplete` / `Steps::FailAttempt` helpers

## Backwards compatibility

- Keep `Scraping::OrchestratorService#call`, but make it:
- create attempt + event_recorder
- delegate to `Scraping::Orchestration::Runner.new(job_listing).call`
- return boolean
- Update `ScrapeJobListingJob` and `RetryService` only if needed for new initialization signatures; otherwise keep them untouched.

## Small allowed behavior improvements (per your 2A)

- Normalize step numbering to be consistent regardless of which branches are taken (implemented by step objects controlling their own ordering).
- Centralize success criteria (confidence thresholds) in `Context` to avoid diverging checks.

## Admin/observability updates

- Ensure new steps continue producing the same event types already present and keep `HtmlScrapingLog` generation in the relevant steps.
- No change required for admin pages unless the controller/view references specific instance vars; keep `attempt.scraping_events` and `attempt.html_scraping_logs` as-is.

## Test plan

- Add/adjust tests to cover:
- Runner executes steps in the expected order.
- Rendered fallback step triggers only when heuristic matches and `Setting.js_rendering_enabled?` is true.
- Selectors step still creates an `HtmlScrapingLog` row.
- Wrapper `Scraping::OrchestratorService` delegates correctly.

## Migration plan (safe incremental refactor)

- Phase 1: Introduce `Context`, `Runner`, and move pure helper methods (heuristic, update_job_listing, complete/fail) into orchestration modules.
- Phase 2: Extract each step into `Steps::*`, wiring through `Runner`.
- Phase 3: Slim `OrchestratorService` down to a wrapper and delete duplicated code paths.
- Phase 4: Run the full test suite and verify admin attempt page still shows timeline + multiple html logs.