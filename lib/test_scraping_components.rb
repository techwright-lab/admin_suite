# frozen_string_literal: true

# Test script for individual scraping components
# Usage: In Rails console, run: load 'lib/test_scraping_components.rb'
# Then call: test_scraping_components('https://www.kaseya.com/careers/jobs/id/5524793004/?gh_jid=5524793004')

module TestScrapingComponents
  def self.test_all(url)
    puts "\n" + "="*80
    puts "Testing Scraping Components for: #{url}"
    puts "="*80 + "\n"

    # Test 1: HTML Fetching
    puts "\n[TEST 1] HTML Fetching Service"
    puts "-" * 80
    test_html_fetching(url)

    # Test 2: Nokogiri HTML Cleaning
    puts "\n[TEST 2] Nokogiri HTML Cleaning Service"
    puts "-" * 80
    test_html_cleaning(url)

    # Test 3: Preliminary Extraction
    puts "\n[TEST 3] Preliminary Extraction Service"
    puts "-" * 80
    test_preliminary_extraction(url)

    # Test 4: Rate Limiter
    puts "\n[TEST 4] Anthropic Rate Limiter Service"
    puts "-" * 80
    test_rate_limiter

    puts "\n" + "="*80
    puts "All component tests completed!"
    puts "="*80 + "\n"
  end

  def self.test_html_fetching(url)
    require "httparty"

    puts "Fetching HTML from: #{url}"
    start_time = Time.current

    begin
      response = HTTParty.get(url, {
        headers: {
          "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        },
        timeout: 30
      })

      duration = Time.current - start_time
      puts "✓ Successfully fetched HTML"
      puts "  Status: #{response.code}"
      puts "  Content Length: #{response.body.length} characters"
      puts "  Duration: #{duration.round(2)}s"
      puts "  Content Type: #{response.headers['content-type']}"

      # Test with HtmlFetcherService
      puts "\n  Testing HtmlFetcherService..."
      company = Company.find_or_create_by!(name: "Kaseya")
      job_role = JobRole.find_or_create_by!(title: "Senior Software Engineer")
      job_listing = JobListing.find_or_create_by!(
        url: url,
        company: company,
        job_role: job_role
      ) do |jl|
        jl.title = "Senior Software Engineer - Ruby on Rails"
      end

      fetcher = Scraping::HtmlFetcherService.new(job_listing)
      result = fetcher.call

      if result[:success]
        puts "  ✓ HtmlFetcherService succeeded"
        puts "    From Cache: #{result[:from_cache]}"
        puts "    HTML Length: #{result[:html_content]&.length || 0} chars"
        puts "    Cleaned HTML Length: #{result[:cleaned_html]&.length || 0} chars"
      else
        puts "  ✗ HtmlFetcherService failed: #{result[:error]}"
      end

      { success: true, html: response.body, response: response }
    rescue => e
      puts "✗ Failed to fetch HTML: #{e.class} - #{e.message}"
      { success: false, error: e.message }
    end
  end

  def self.test_html_cleaning(url)
    # Fetch HTML first
    fetch_result = test_html_fetching(url)
    return unless fetch_result[:success]

    html = fetch_result[:html]
    puts "\n  Testing NokogiriHtmlCleanerService..."

    begin
      cleaner = Scraping::NokogiriHtmlCleanerService.new
      cleaned = cleaner.clean(html)

      puts "  ✓ HTML cleaning succeeded"
      puts "    Original Length: #{html.length} characters"
      puts "    Cleaned Length: #{cleaned.length} characters"
      puts "    Reduction: #{((1 - cleaned.length.to_f / html.length) * 100).round(2)}%"
      puts "    Estimated Tokens: #{(cleaned.length / 3.0).ceil}"

      # Show first 500 chars of cleaned text
      puts "\n  First 500 characters of cleaned text:"
      puts "  " + "-" * 76
      puts "  #{cleaned[0..500].gsub(/\n/, ' ').strip}"
      puts "  " + "-" * 76

      { success: true, cleaned: cleaned }
    rescue => e
      puts "  ✗ HTML cleaning failed: #{e.class} - #{e.message}"
      puts "  #{e.backtrace.first(3).join("\n  ")}"
      { success: false, error: e.message }
    end
  end

  def self.test_preliminary_extraction(url)
    # Fetch HTML first
    fetch_result = test_html_fetching(url)
    return unless fetch_result[:success]

    html = fetch_result[:html]
    puts "\n  Testing HtmlScrapingService..."

    begin
      extractor = Scraping::HtmlScrapingService.new
      data = extractor.extract(html, url)

      puts "  ✓ Preliminary extraction succeeded"
      puts "  Extracted fields:"
      data.each do |key, value|
        if value.is_a?(String) && value.length > 100
          puts "    #{key}: #{value[0..100]}..."
        else
          puts "    #{key}: #{value.inspect}"
        end
      end

      if data.empty?
        puts "  ⚠ No data extracted (this is okay, extraction may need refinement)"
      end

      { success: true, data: data }
    rescue => e
      puts "  ✗ Preliminary extraction failed: #{e.class} - #{e.message}"
      puts "  #{e.backtrace.first(3).join("\n  ")}"
      { success: false, error: e.message }
    end
  end

  def self.test_rate_limiter
    puts "  Testing AnthropicRateLimiterService..."

    begin
      limiter = Scraping::AnthropicRateLimiterService.new

      # Test current usage
      current_usage = limiter.total_usage_in_window
      puts "  Current token usage (last 60s): #{current_usage} / 30,000"

      # Test can_send_tokens?
      test_tokens = [ 1000, 5000, 10000, 20000, 30000 ]
      test_tokens.each do |tokens|
        can_send = limiter.can_send_tokens?(tokens)
        wait_time = limiter.wait_time_for_tokens(tokens)
        status = can_send ? "✓" : "✗"
        puts "    #{status} Can send #{tokens} tokens? #{can_send} (wait: #{wait_time.round(2)}s)"
      end

      # Test recording tokens
      puts "\n  Recording 5000 tokens..."
      limiter.record_tokens_used(5000)
      new_usage = limiter.total_usage_in_window
      puts "  New usage: #{new_usage} / 30,000"

      { success: true, usage: new_usage }
    rescue => e
      puts "  ✗ Rate limiter test failed: #{e.class} - #{e.message}"
      puts "  #{e.backtrace.first(3).join("\n  ")}"
      { success: false, error: e.message }
    end
  end

  # Convenience method for Rails console
  def self.test_single_component(component, url = nil)
    case component.to_s.downcase
    when "html_fetch", "fetch"
      test_html_fetching(url || "https://www.kaseya.com/careers/jobs/id/5524793004/?gh_jid=5524793004")
    when "html_clean", "clean"
      test_html_cleaning(url || "https://www.kaseya.com/careers/jobs/id/5524793004/?gh_jid=5524793004")
    when "preliminary", "extract"
      test_preliminary_extraction(url || "https://www.kaseya.com/careers/jobs/id/5524793004/?gh_jid=5524793004")
    when "rate_limiter", "limiter"
      test_rate_limiter
    else
      puts "Unknown component: #{component}"
      puts "Available: html_fetch, html_clean, preliminary, rate_limiter"
    end
  end
end

# Make it available in Rails console
def test_scraping_components(url = "https://www.kaseya.com/careers/jobs/id/5524793004/?gh_jid=5524793004")
  TestScrapingComponents.test_all(url)
end

def test_component(component, url = nil)
  TestScrapingComponents.test_single_component(component, url)
end

puts "Test helpers loaded! Use:"
puts "  test_scraping_components('URL') - Test all components"
puts "  test_component('html_fetch', 'URL') - Test HTML fetching"
puts "  test_component('html_clean', 'URL') - Test HTML cleaning"
puts "  test_component('preliminary', 'URL') - Test preliminary extraction"
puts "  test_component('rate_limiter') - Test rate limiter"
