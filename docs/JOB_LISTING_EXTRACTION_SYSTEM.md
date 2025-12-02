# Job Listing Data Extraction System

## Overview

A comprehensive, production-ready system for extracting structured data from job listings using AI-powered extraction and API integrations. All configuration is database-backed for runtime changes without redeployment.

## Architecture

### Data Flow

1. **User submits job URL** → InterviewApplication created
2. **ScrapeJobListingJob queued** → Background processing
3. **Orchestration begins**:
   - Detect job board type (LinkedIn, Greenhouse, Lever, etc.)
   - Try API extraction if supported (Greenhouse, Lever)
   - Check robots.txt compliance and rate limits
   - Fall back to AI extraction with LLM providers
4. **Results stored** → JobListing updated, ScrapingAttempt logged
5. **Admin review** → Failed extractions flagged in DLQ

## Key Features

### ✅ Dynamic Configuration (Database-Backed)

- **LLM Providers**: Configure AI providers in production via Avo admin
  - Switch between Claude, GPT-4o, o1, Ollama models
  - Adjust temperature, max tokens, priority
  - Enable/disable providers on the fly

- **Extraction Prompts**: Modify prompts without code deployment
  - Version control for A/B testing
  - Template variables for dynamic content
  - One active template at a time

### ✅ Multi-Provider Support

**API Integrations:**
- Greenhouse (public API)
- Lever (public API)
- Extensible for more job boards

**AI Providers:**
- Anthropic Claude (3.7 Sonnet)
- OpenAI (GPT-4o, o1)
- Ollama (self-hosted: Llama 3.3, Qwen 2.5)
- Automatic fallback chain

### ✅ Respectful Scraping

- **Rate Limiting**: Per-domain limits configurable in `config/rate_limits.yml`
- **Robots.txt Compliance**: Automatic checking and caching
- **Proper Headers**: User-agent, timeouts, redirect limits
- **Exponential Backoff**: On errors

### ✅ State Management (AASM)

**ScrapingAttempt States:**
- `pending` → `fetching` → `extracting` → `completed`
- `failed` → `retrying` (up to 3 times)
- `dead_letter` (DLQ for admin review)
- `manual` (admin resolved)

### ✅ Observability

**Metrics Dashboard** (`/admin/scraping_metrics`):
- Success rates by domain (last 7 days)
- Provider performance comparison
- Average extraction times
- DLQ count and items needing review
- Recent failures with details

**Detailed Logging:**
- Every extraction attempt tracked in database
- HTTP status codes, errors, confidence scores
- Request/response metadata
- Provider and model used
- Token usage for cost tracking

### ✅ Admin Interface (Avo)

**ScrapingAttempt Resource:**
- Filter by status, domain, date range
- View extraction metadata and errors
- Retry failed attempts
- Mark as manually resolved

**JobListing Resource:**
- Extraction status badges
- Confidence scores
- Re-extract action
- Mark as verified action
- View all scraping attempts

**LlmProviderConfig Resource:**
- Enable/disable providers
- Change models and parameters
- Set priority order
- View API key status
- Test provider functionality

**ExtractionPromptTemplate Resource:**
- Create/edit prompt templates
- Activate templates
- Duplicate for versioning
- View template variables

## File Structure

```
app/
├── models/
│   ├── scraping_attempt.rb              # AASM state machine for tracking
│   ├── llm_provider_config.rb           # Dynamic LLM configuration
│   ├── extraction_prompt_template.rb    # Dynamic prompt management
│   └── job_listing.rb                   # Enhanced with extraction methods
├── services/
│   ├── scraping/
│   │   ├── orchestrator_service.rb      # Main extraction coordinator
│   │   ├── job_board_detector_service.rb
│   │   ├── ai_job_extractor_service.rb
│   │   ├── rate_limiter_service.rb
│   │   └── robots_txt_checker_service.rb
│   ├── llm_providers/
│   │   ├── base_provider.rb             # Abstract provider interface
│   │   ├── openai_provider.rb
│   │   ├── anthropic_provider.rb
│   │   └── ollama_provider.rb
│   ├── api_fetchers/
│   │   ├── base_fetcher.rb
│   │   ├── greenhouse_fetcher.rb
│   │   └── lever_fetcher.rb
│   └── job_listing_scraper_service.rb   # Legacy compatibility
├── jobs/
│   └── scrape_job_listing_job.rb        # Background processing with DLQ
├── avo/
│   ├── resources/
│   │   ├── scraping_attempt.rb
│   │   ├── llm_provider_config.rb
│   │   └── extraction_prompt_template.rb
│   └── actions/
│       ├── retry_extraction.rb
│       ├── mark_as_manual.rb
│       ├── re_extract_job_listing.rb
│       ├── mark_job_listing_as_verified.rb
│       ├── test_llm_provider.rb
│       ├── activate_prompt_template.rb
│       └── duplicate_prompt_template.rb
└── controllers/
    └── admin/
        └── scraping_metrics_controller.rb

config/
├── rate_limits.yml                      # Per-domain rate limits
└── credentials.example.yml              # API keys structure

db/
└── seeds/
    └── llm_provider_configs.rb          # Default configurations
```

## Database Schema

### scraping_attempts
- Tracks every extraction attempt
- AASM state column with transitions
- HTTP status, errors, duration
- Confidence scores and metadata
- Provider and model information

### llm_provider_configs
- Runtime-configurable AI providers
- Model, temperature, max_tokens
- Priority ordering for fallback
- Custom settings JSONB

### extraction_prompt_templates
- Versionable prompt templates
- Template variables ({{url}}, {{html_content}})
- Active flag (only one active)

## Usage Examples

### For Users
```ruby
# Create application with job URL
application = user.interview_applications.create!(
  company: company,
  job_role: job_role
)

# Trigger extraction
CreateJobListingFromUrlService.new(
  application,
  "https://jobs.lever.co/company/job-id"
).call
```

### For Admins

**Change AI Provider:**
```ruby
# Via Avo UI: /avo/resources/llm_provider_configs
# Or programmatically:
LlmProviderConfig.find_by(provider_type: "anthropic").update!(
  llm_model: "claude-3-7-sonnet-20250219",
  max_tokens: 8192,
  enabled: true
)
```

**Update Extraction Prompt:**
```ruby
# Via Avo UI: /avo/resources/extraction_prompt_templates
# Or programmatically:
template = ExtractionPromptTemplate.create!(
  name: "Enhanced Extraction v2",
  prompt_template: "Your improved prompt here...",
  active: true,
  version: 2
)
```

**Monitor Failures:**
```ruby
# View metrics dashboard
# Visit: /admin/scraping_metrics

# Or query programmatically:
ScrapingAttempt.where(status: :dead_letter).count
ScrapingAttempt.success_rate_for_domain("linkedin.com", 7)
```

## Configuration

### API Keys

Add to encrypted credentials:
```bash
rails credentials:edit
```

```yaml
openai:
  api_key: sk-...
anthropic:
  api_key: sk-ant-...
greenhouse:
  api_token: optional
lever:
  api_token: optional
```

### Rate Limits

Edit `config/rate_limits.yml`:
```yaml
default: 5  # seconds between requests

domains:
  "linkedin.com": 10
  "indeed.com": 8
  "greenhouse.io": 5
```

### Seed Default Configs

```bash
rails runner "load Rails.root.join('db/seeds/llm_provider_configs.rb')"
```

## Testing

Comprehensive test coverage:
- Model state transitions
- Rate limiting behavior
- Job board detection
- Service integration tests
- Factory definitions

```bash
rails test test/models/scraping_attempt_test.rb
rails test test/services/scraping/
rails test test/jobs/scrape_job_listing_job_test.rb
```

## Future Enhancements

- [ ] Browser automation (Playwright) for JavaScript-heavy sites
- [ ] Webhook notifications for DLQ items
- [ ] A/B testing framework for prompts
- [ ] Fine-tuned models for specific job boards
- [ ] Bulk re-extraction tool
- [ ] Chrome extension for quick import
- [ ] Real-time extraction status via ActionCable

## Support

For issues or questions:
1. Check `/admin/scraping_metrics` dashboard
2. Review ScrapingAttempt errors in Avo
3. Verify API keys in credentials
4. Check rate limits aren't blocking domains

