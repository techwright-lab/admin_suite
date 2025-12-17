# frozen_string_literal: true

require "nokogiri"

module Scraping
  # Service for cleaning HTML content using Nokogiri
  #
  # Extracts main content, removes unwanted elements, and optimizes
  # for LLM token limits. Uses semantic HTML5 elements and common
  # job board patterns to find the main content area.
  #
  # For board-specific cleaning, use HtmlCleaners::CleanerFactory instead.
  #
  # @example Basic usage
  #   cleaner = Scraping::NokogiriHtmlCleanerService.new
  #   cleaned_text = cleaner.clean(html_content)
  #
  # @example Board-specific cleaning
  #   cleaner = Scraping::HtmlCleaners::CleanerFactory.cleaner_for(:ashbyhq)
  #   cleaned_text = cleaner.clean(html_content)
  class NokogiriHtmlCleanerService
    MAX_TOKENS = 25_000 # Conservative limit to stay under 30k tokens/minute
    CHARS_PER_TOKEN = 3 # Conservative estimate: 1 token ≈ 3 chars for HTML

    # Cleans HTML content and returns optimized text
    #
    # @param [String] html_content The raw HTML content
    # @return [String] Cleaned text content optimized for LLM
    def clean(html_content)
      return "" if html_content.blank?

      doc = Nokogiri::HTML(html_content)

      # Remove unwanted elements first
      remove_unwanted_elements(doc)

      # Extract main content
      main_content = extract_main_content(doc)

      # Convert to text and clean up whitespace
      text = main_content.text
      text = normalize_whitespace(text)

      # Truncate to token limit
      truncate_to_token_limit(text, MAX_TOKENS)
    end

    private

    # Removes unwanted elements from the document
    #
    # @param [Nokogiri::HTML::Document] doc The parsed HTML document
    def remove_unwanted_elements(doc)
      # Remove script and style tags
      doc.css("script, style").remove

      # Remove navigation elements
      doc.css("nav, header, footer").remove

      # Remove common ad/tracking containers
      doc.css("[class*='ad'], [class*='advertisement'], [id*='ad'], [id*='advertisement']").remove
      doc.css("[class*='tracking'], [class*='analytics'], [id*='tracking']").remove

      # Remove social media widgets
      doc.css("[class*='social'], [class*='share'], [id*='social'], [id*='share']").remove

      # Remove comments
      doc.xpath("//comment()").remove

      # Remove hidden elements
      doc.css("[style*='display:none'], [style*='display: none'], [hidden]").remove
    end

    # Extracts the main content area from the document
    #
    # @param [Nokogiri::HTML::Document] doc The parsed HTML document
    # @return [Nokogiri::XML::Node] The main content node
    def extract_main_content(doc)
      # Minimum content length threshold - skip elements with too little text
      min_content_length = 100

      # Try semantic HTML5 elements first
      main = doc.css("main, article, [role='main']").first
      return main if main && main.text.strip.length >= min_content_length

      # Try common content class names
      content = doc.css(".content, #content, .main-content, .job-content, .job-description").first
      return content if content && content.text.strip.length >= min_content_length

      # Try React/SPA root containers (common for Ashby, Greenhouse, Lever, etc.)
      # Check these BEFORE job-specific selectors as they usually contain the full content
      react_root = doc.css("#root, #app, #__next").first
      return react_root if react_root && react_root.text.strip.length >= min_content_length

      # Try container patterns with dynamic class names (e.g., _container_xyz, _content_xyz)
      container = doc.css("[class*='container'], [class*='content'], [class*='posting']").first
      return container if container && container.text.strip.length >= min_content_length

      # Try job-specific selectors (be careful - these can match small nav elements)
      job_content = doc.css("[class*='job-description'], [class*='job-details'], [class*='job-posting'], [id*='job-description']").first
      return job_content if job_content && job_content.text.strip.length >= min_content_length

      # Try to find the largest text-containing div
      body = doc.css("body").first || doc
      largest_div = find_largest_content_div(body)
      return largest_div if largest_div && largest_div.text.strip.length >= min_content_length

      # Fallback to body
      body
    end

    # Finds the div with the most text content (likely the main content area)
    #
    # @param [Nokogiri::XML::Node] parent The parent node to search within
    # @return [Nokogiri::XML::Node, nil] The largest content div or nil
    def find_largest_content_div(parent)
      return nil unless parent

      divs = parent.css("div")
      return nil if divs.empty?

      # Find the div with the most text content
      divs.max_by { |div| div.text.strip.length }
    end

    # Normalizes whitespace in text
    #
    # @param [String] text The text to normalize
    # @return [String] Normalized text
    def normalize_whitespace(text)
      # Replace multiple spaces with single space
      text = text.gsub(/[ \t]+/, " ")

      # Replace multiple newlines with double newline (paragraph break)
      text = text.gsub(/\n{3,}/, "\n\n")

      # Remove leading/trailing whitespace from each line
      text = text.split("\n").map(&:strip).join("\n")

      # Final cleanup
      text.strip
    end

    # Truncates text to stay within token limit
    #
    # @param [String] text The text to truncate
    # @param [Integer] max_tokens Maximum tokens allowed
    # @return [String] Truncated text
    def truncate_to_token_limit(text, max_tokens)
      max_chars = max_tokens * CHARS_PER_TOKEN

      return text if text.length <= max_chars

      # Truncate to max length
      truncated = text[0...max_chars]

      # Try to end at a sentence boundary
      truncated = truncated.sub(/\.[^.]*$/, ".")

      # If still too long, truncate more aggressively
      while estimate_tokens(truncated) > max_tokens && truncated.length > 10_000
        truncated = truncated[0...(truncated.length * 0.9).to_i]
        truncated = truncated.sub(/\.[^.]*$/, ".")
      end

      truncated
    end

    # Estimates token count for text
    #
    # @param [String] text The text to estimate
    # @return [Integer] Estimated token count
    def estimate_tokens(text)
      (text.length.to_f / CHARS_PER_TOKEN).ceil
    end
  end
end
