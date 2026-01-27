# Testing Scraping Components

This guide explains how to test individual scraping components using the test script.

## Quick Start

1. Open Rails console:
```bash
bin/rails console
```

2. Load the test script:
```ruby
load 'lib/test_scraping_components.rb'
```

3. Test all components:
```ruby
test_scraping_components('https://www.kaseya.com/careers/jobs/id/5524793004/?gh_jid=5524793004')
```

4. Or test individual components:
```ruby
# Test HTML fetching
test_component('html_fetch', 'https://www.kaseya.com/careers/jobs/id/5524793004/?gh_jid=5524793004')

# Test HTML cleaning
test_component('html_clean', 'https://www.kaseya.com/careers/jobs/id/5524793004/?gh_jid=5524793004')

# Test preliminary extraction
test_component('preliminary', 'https://www.kaseya.com/careers/jobs/id/5524793004/?gh_jid=5524793004')

# Test rate limiter (no URL needed)
test_component('rate_limiter')
```

## Components Being Tested

### 1. HTML Fetching Service
- Tests direct HTTP fetching with HTTParty
- Tests `Scraping::HtmlFetcherService` with caching
- Verifies cache behavior and HTML retrieval

### 2. Nokogiri HTML Cleaning Service
- Tests `Scraping::NokogiriHtmlCleanerService`
- Shows HTML reduction percentage
- Displays cleaned text preview
- Estimates token count

### 3. HTML Scraping Service
- Tests `Scraping::HtmlScrapingService`
- Extracts: title, location, remote_type, salary, description, company_name
- Shows all extracted fields

### 4. Anthropic Rate Limiter Service
- Tests `Scraping::AnthropicRateLimiterService`
- Shows current token usage
- Tests can_send_tokens? for various token amounts
- Tests token recording

## Manual Testing in Console

You can also test components manually:

```ruby
# 1. HTML Fetching
company = Company.find_or_create_by!(name: "Kaseya")
job_role = JobRole.find_or_create_by!(title: "Senior Software Engineer")
job_listing = JobListing.create!(
  url: "https://www.kaseya.com/careers/jobs/id/5524793004/?gh_jid=5524793004",
  company: company,
  job_role: job_role
)

fetcher = Scraping::HtmlFetcherService.new(job_listing)
result = fetcher.call
puts result.inspect

# 2. HTML Cleaning
html = result[:html_content]
cleaner = Scraping::NokogiriHtmlCleanerService.new
cleaned = cleaner.clean(html)
puts "Original: #{html.length} chars"
puts "Cleaned: #{cleaned.length} chars"

# 3. HTML Scraping
extractor = Scraping::HtmlScrapingService.new
data = extractor.extract(html, job_listing.url)
puts data.inspect

# 4. Rate Limiter
limiter = Scraping::AnthropicRateLimiterService.new
puts "Can send 10000 tokens? #{limiter.can_send_tokens?(10000)}"
puts "Current usage: #{limiter.total_usage_in_window}"
```

## Expected Output

When running `test_scraping_components`, you should see:

1. **HTML Fetching**: Status code, content length, duration, cache status
2. **HTML Cleaning**: Original vs cleaned length, reduction percentage, token estimate, preview
3. **HTML Scraping**: All extracted fields with their values
4. **Rate Limiter**: Current usage, can_send_tokens tests, token recording

## Troubleshooting

### Service not found errors
- Make sure you've run `bundle install` to install Nokogiri
- Restart Rails console if services were just created

### HTML fetch failures
- Check internet connection
- Verify URL is accessible
- Check for rate limiting or blocking

### No data extracted
- This is normal for HTML scraping - it's a best-effort service
- The AI extraction will still work even if HTML scraping finds nothing

## Next Steps

After testing individual components, you can test the full orchestrator:

```ruby
orchestrator = Scraping::OrchestratorService.new(job_listing)
success = orchestrator.call
```


