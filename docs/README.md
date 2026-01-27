# Gleania Documentation

This folder contains all project documentation, progress reports, and technical specifications.

## Folder-based organization (Developer Portal docs viewer)

The Developer Portal docs viewer automatically groups docs into sidebar sections based on the **top-level folder** under `docs/`.

- `docs/cicd/*` → **CICD**
- `docs/features/*` → **Features**
- (future) `docs/billing/*` → **Billing**, etc.

Docs that live directly under `docs/*.md` are grouped using filename conventions for backward compatibility (e.g. `ASSISTANT_*`, `GOOGLE_*`, `TEST*`), but the preferred long-term approach is **folders**.

## 📚 Documentation Index

### 🛠️ Developer Portal (Admin)
- **[DEVELOPER_PORTAL_OVERVIEW.md](DEVELOPER_PORTAL_OVERVIEW.md)** - Overview of the admin portal architecture
- **[DEVELOPER_PORTAL_ADDING_RESOURCES.md](DEVELOPER_PORTAL_ADDING_RESOURCES.md)** - Guide for adding new admin resources

### 🤖 Assistant System
- **[ASSISTANT_OVERVIEW.md](ASSISTANT_OVERVIEW.md)** - AI Assistant architecture and features
- **[ASSISTANT_ADDING_TOOLS.md](ASSISTANT_ADDING_TOOLS.md)** - How to add new tools to the assistant
- **[ASSISTANT_DEBUGGING.md](ASSISTANT_DEBUGGING.md)** - Debugging assistant issues
- **[ASSISTANT_EVALUATIONS.md](ASSISTANT_EVALUATIONS.md)** - Assistant evaluation framework

### 🎯 Current Status & Progress
- **[PROGRESS_REVIEW.md](PROGRESS_REVIEW.md)** - Overall project progress and next steps
- **[CONTROLLERS_COMPLETE.md](CONTROLLERS_COMPLETE.md)** - Controllers & routes implementation report

### 🗄️ Database & Models
- **[MIGRATION_SUCCESS.md](MIGRATION_SUCCESS.md)** - Database migration completion report
- **[REFACTORING_PROGRESS.md](REFACTORING_PROGRESS.md)** - Model refactoring documentation

### 🧪 Testing
- **[TEST_COMPLETION_REPORT.md](TEST_COMPLETION_REPORT.md)** - Final test results
- **[TEST_REVIEW.md](TEST_REVIEW.md)** - Comprehensive test analysis
- **[TEST_STATUS.md](TEST_STATUS.md)** - Test status and missing tests

### 🎨 UI/UX Design
- **[KANBAN_DESIGN.md](KANBAN_DESIGN.md)** - Kanban board design and pipeline stages
- **[AUTOCOMPLETE_DESIGN.md](AUTOCOMPLETE_DESIGN.md)** - Autocomplete component design

### 🔐 Authentication & Security
- **[`security/DATA_CLASSIFICATION_POLICY.md`](security/DATA_CLASSIFICATION_POLICY.md)** - Data classification levels and handling requirements
- **[`security/DATA_INVENTORY.md`](security/DATA_INVENTORY.md)** - Data inventory / data map (elements → protection levels)
- **[GOOGLE_OAUTH_SETUP.md](GOOGLE_OAUTH_SETUP.md)** - Google OAuth configuration
- **[TURNSTILE_SETUP.md](TURNSTILE_SETUP.md)** - Cloudflare Turnstile setup

### ⚙️ Systems
- **[JOB_LISTING_EXTRACTION_SYSTEM.md](JOB_LISTING_EXTRACTION_SYSTEM.md)** - Job listing scraping and extraction

### 🚀 CI/CD
- **[`cicd/RUNBOOK.md`](cicd/RUNBOOK.md)** - CI/CD runbooks index (CASA Tier 2 evidence)
- **[`cicd/runbooks/01_CI.md`](cicd/runbooks/01_CI.md)** - CI process (GitHub Actions)
- **[`cicd/runbooks/02_DEPLOYMENT.md`](cicd/runbooks/02_DEPLOYMENT.md)** - Deployment process (Kamal)
- **[`cicd/runbooks/03_SECRETS_AND_CREDENTIALS.md`](cicd/runbooks/03_SECRETS_AND_CREDENTIALS.md)** - Secrets management (Rails encrypted credentials)

---

## 📖 Quick Start

### For Developers
1. **Admin Portal:** See [DEVELOPER_PORTAL_OVERVIEW.md](DEVELOPER_PORTAL_OVERVIEW.md)
2. **Adding Admin Resources:** See [DEVELOPER_PORTAL_ADDING_RESOURCES.md](DEVELOPER_PORTAL_ADDING_RESOURCES.md)
3. **Assistant Tools:** See [ASSISTANT_ADDING_TOOLS.md](ASSISTANT_ADDING_TOOLS.md)

### For Project Overview
1. **Progress:** See [PROGRESS_REVIEW.md](PROGRESS_REVIEW.md)
2. **Database:** See [MIGRATION_SUCCESS.md](MIGRATION_SUCCESS.md)
3. **Testing:** See [TEST_COMPLETION_REPORT.md](TEST_COMPLETION_REPORT.md)

---

## 🔄 Last Updated

December 25, 2024

