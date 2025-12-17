# frozen_string_literal: true

require "nokogiri"

module Scraping
  module HtmlCleaners
    # Base HTML cleaner for extracting main content from job board pages.
    #
    # Subclasses can override selectors and behavior for specific job boards.
    # This provides optimized content extraction for LLM processing.
    class BaseCleaner
      MAX_TOKENS = 25_000
      CHARS_PER_TOKEN = 3
      MIN_CONTENT_LENGTH = 100

      def initialize(board_type: :unknown)
        @board_type = board_type
      end

      # Cleans HTML content and returns optimized text for LLM
      #
      # @param html_content [String] Raw HTML content
      # @return [String] Cleaned text content
      def clean(html_content)
        return "" if html_content.blank?

        doc = Nokogiri::HTML(html_content)
        remove_unwanted_elements(doc)
        main_content = extract_main_content(doc)
        text = main_content.text
        text = normalize_whitespace(text)
        truncate_to_token_limit(text, MAX_TOKENS)
      end

      protected

      # Elements to remove (scripts, styles, navigation, etc.)
      #
      # @return [Array<String>] CSS selectors to remove
      def elements_to_remove
        [
          "script", "style", "noscript",
          "nav", "header", "footer",
          "[class*='cookie']", "[id*='cookie']",
          "[class*='popup']", "[id*='popup']",
          "[class*='modal']", "[id*='modal']",
          "[style*='display:none']", "[style*='display: none']", "[hidden]"
        ]
      end

      # Selectors for main content area (in priority order)
      #
      # @return [Array<String>] CSS selectors for main content
      def main_content_selectors
        [
          "main", "article", "[role='main']",
          ".content", "#content", ".main-content",
          "#root", "#app", "#__next",
          "[class*='container']", "[class*='content']",
          "body"
        ]
      end

      # Elements to preserve even if they match removal patterns
      #
      # @return [Array<String>] CSS selectors to preserve
      def elements_to_preserve
        []
      end

      private

      def remove_unwanted_elements(doc)
        elements_to_remove.each do |selector|
          doc.css(selector).each do |el|
            # Don't remove if it matches a preservation selector
            next if elements_to_preserve.any? { |p| el.matches?(p) rescue false }
            el.remove
          end
        end
        doc.xpath("//comment()").remove
      end

      def extract_main_content(doc)
        main_content_selectors.each do |selector|
          node = doc.css(selector).first
          next unless node
          next unless node.text.strip.length >= MIN_CONTENT_LENGTH

          return node
        end

        # Fallback to largest div
        body = doc.css("body").first || doc
        find_largest_content_div(body) || body
      end

      def find_largest_content_div(parent)
        return nil unless parent

        divs = parent.css("div")
        return nil if divs.empty?

        divs.max_by { |div| div.text.strip.length }
      end

      def normalize_whitespace(text)
        text = text.gsub(/[ \t]+/, " ")
        text = text.gsub(/\n{3,}/, "\n\n")
        text = text.split("\n").map(&:strip).join("\n")
        text.strip
      end

      def truncate_to_token_limit(text, max_tokens)
        max_chars = max_tokens * CHARS_PER_TOKEN
        return text if text.length <= max_chars

        truncated = text[0...max_chars]
        truncated = truncated.sub(/\.[^.]*$/, ".")
        truncated
      end
    end
  end
end
