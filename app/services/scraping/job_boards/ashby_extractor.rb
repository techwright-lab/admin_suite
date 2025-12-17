# frozen_string_literal: true

module Scraping
  module JobBoards
    # Extractor for Ashby job board pages (jobs.ashbyhq.com)
    #
    # Ashby uses React with dynamically generated class names like `_title_ud4nd_34`
    # but also has stable semantic classes like `ashby-job-posting-heading`.
    #
    # Page structure:
    # - Header: Company logo with alt text, back button
    # - Left pane (.ashby-job-posting-left-pane): Location, Employment Type, Location Type, Department
    # - Right pane (.ashby-job-posting-right-pane): Full job description with h2 sections
    # - Title in h1 with class containing "_title_" or .ashby-job-posting-heading
    # - Company name: In title tag after "@" or in logo img[alt]
    #
    # NOTE: This extractor focuses on metadata extraction (title, company, location).
    # The job description contains structured sections (Responsibilities, Requirements)
    # that are better parsed by AI extraction. We intentionally return only the raw
    # description to let AI handle the structured extraction.
    class AshbyExtractor < BaseExtractor
      protected

      def title_selectors
        [
          ".ashby-job-posting-heading",
          "h1[class*='_title_']",
          "h1",
          "meta[property='og:title']"
        ]
      end

      def company_selectors
        [
          # Company name is in the logo alt text
          ".ashby-job-posting-header img[alt]",
          "[class*='_navLogoWordmarkImage_']",
          # Or extract from title tag pattern "Job Title @ Company"
          "title"
        ]
      end

      def location_selectors
        [
          # Left pane sections have Location heading
          ".ashby-job-posting-left-pane [class*='_section_']:first-of-type p",
          "[class*='_section_'] p",
          "meta[property='og:locale']"
        ]
      end

      def description_selectors
        [
          ".ashby-job-posting-right-pane",
          "[class*='_details_']",
          "[class*='_content_']",
          "meta[name='description']"
        ]
      end

      # Ashby embeds about_company in the description - don't duplicate
      # Let AI extraction parse this from the description content
      def about_company_selectors
        []
      end

      # Requirements are in h2 sections within the description
      # Let AI extraction parse these from the description content
      def requirements_selectors
        []
      end

      # Responsibilities are in h2 sections within the description
      # Let AI extraction parse these from the description content
      def responsibilities_selectors
        []
      end

      # Ashby has company culture info embedded in description
      def company_culture_selectors
        []
      end

      # Override confidence calculation for Ashby
      #
      # Ashby HTML extraction only gives us metadata (title, company, location)
      # and raw description. The structured fields (requirements, responsibilities)
      # need AI extraction to parse from the description content.
      #
      # Cap confidence at 0.65 to ensure AI extraction runs for structured parsing.
      def confidence_for(data)
        base_score = super(data)

        # If we only have basic metadata, cap confidence to trigger AI extraction
        has_structured_data = data[:requirements].present? || data[:responsibilities].present?
        return base_score if has_structured_data

        # Cap at 0.65 to ensure AI extraction runs for structured parsing
        [ base_score, 0.65 ].min
      end

      private

      # Override pick_text to handle special cases for Ashby
      def pick_text(doc, selectors, selectors_tried, field)
        selectors_tried[field.to_s] = []

        selectors.each do |selector|
          selectors_tried[field.to_s] << selector
          node = doc.css(selector).first
          next unless node

          # Handle special extraction for company from title tag
          if field == :company_name && selector == "title"
            title_text = node.text.to_s
            # Extract company from "Job Title @ Company" pattern
            if title_text.include?("@")
              company = title_text.split("@").last&.strip
              return company if company.present?
            end
            next
          end

          # Handle img alt attribute for company logo
          if node.name == "img" && node["alt"].present?
            return node["alt"].strip
          end

          # Handle meta tags
          raw = node["content"] || node["alt"] || node["aria-label"] || node["title"] || node.text
          text = raw.to_s.squish

          # For short fields (location), accept shorter values
          # For long fields (description), require more content
          min_length = case field
          when :description
            50
          else
            1  # Accept any non-empty value for short fields
          end

          return text if text.present? && text.length >= min_length
        end
        nil
      end
    end
  end
end
