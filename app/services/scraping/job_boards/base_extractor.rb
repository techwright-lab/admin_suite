# frozen_string_literal: true

require "nokogiri"

module Scraping
  module JobBoards
    # Base extractor for job-board HTML pages using selectors-first strategy.
    #
    # Subclasses should provide selector lists for key fields.
    class BaseExtractor
      REQUIRED_FIELDS = %i[title company_name description].freeze
      IMPORTANT_FIELDS = %i[location requirements responsibilities benefits].freeze

      attr_reader :board_type

      def initialize(board_type:)
        @board_type = board_type
      end

      # Extracts structured data from HTML
      #
      # @param html_content [String]
      # @return [Hash] normalized extraction result
      def extract(html_content)
        return failure("No HTML provided") if html_content.blank?

        doc = Nokogiri::HTML(html_content)
        selectors_tried = {}

        data = {
          title: pick_text(doc, title_selectors, selectors_tried, :title),
          company_name: pick_text(doc, company_selectors, selectors_tried, :company_name),
          location: pick_text(doc, location_selectors, selectors_tried, :location),
          description: pick_text(doc, description_selectors, selectors_tried, :description),
          about_company: pick_text(doc, about_company_selectors, selectors_tried, :about_company),
          company_culture: pick_text(doc, company_culture_selectors, selectors_tried, :company_culture),
          requirements: pick_text(doc, requirements_selectors, selectors_tried, :requirements),
          responsibilities: pick_text(doc, responsibilities_selectors, selectors_tried, :responsibilities)
        }.compact

        missing_fields = REQUIRED_FIELDS.reject { |f| data[f].present? }
        confidence = confidence_for(data)

        {
          # success here means "required fields present"; acceptance is decided by orchestrator via confidence threshold.
          success: missing_fields.empty?,
          extractor_kind: "job_board_selectors",
          board_type: board_type.to_s,
          extraction_method: "html",
          provider: board_type.to_s,
          confidence: confidence,
          missing_fields: missing_fields.map(&:to_s),
          extracted_fields: data.keys.map(&:to_s),
          selectors_tried: selectors_tried,
          data: data
        }
      rescue StandardError => e
        failure(e.message)
      end

      protected

      def title_selectors
        [ "h1" ]
      end

      def company_selectors
        []
      end

      def location_selectors
        [ "[class*='location']", "[data-location]", "address" ]
      end

      def description_selectors
        [ "[class*='description']", "[data-description]", "main", "article" ]
      end

      def requirements_selectors
        []
      end

      def responsibilities_selectors
        []
      end

      def about_company_selectors
        [
          "[id*='about']",
          "[class*='about']",
          ".about",
          ".about-us"
        ]
      end

      def company_culture_selectors
        [
          "[id*='culture']",
          "[class*='culture']",
          "[id*='values']",
          "[class*='values']",
          "[id*='mission']",
          "[class*='mission']"
        ]
      end

      def confidence_for(data)
        # Weighted score emphasizing must-have fields.
        weights = {
          title: 0.25,
          company_name: 0.25,
          description: 0.15,
          location: 0.05,
          requirements: 0.075,
          responsibilities: 0.075,
          benefits: 0.05,
          about_company: 0.05,
          company_culture: 0.05
        }

        score = weights.sum { |field, w| data[field].present? ? w : 0.0 }

        # If any required field is missing, cap confidence so we continue to AI.
        missing_required = REQUIRED_FIELDS.any? { |f| data[f].blank? }
        score = [ score, 0.69 ].min if missing_required

        score.clamp(0.0, 1.0)
      end

      private

      def pick_text(doc, selectors, selectors_tried, field)
        selectors_tried[field.to_s] = []
        selectors.each do |selector|
          selectors_tried[field.to_s] << selector
          node = doc.css(selector).first
          next unless node

          raw = node["content"] || node["alt"] || node["aria-label"] || node["title"] || node.text
          text = raw.to_s.squish
          return text if text.present?
        end
        nil
      end

      def failure(message)
        {
          success: false,
          extractor_kind: "job_board_selectors",
          board_type: board_type.to_s,
          extraction_method: "html",
          provider: board_type.to_s,
          confidence: 0.0,
          error: message,
          missing_fields: REQUIRED_FIELDS.map(&:to_s),
          extracted_fields: [],
          selectors_tried: {},
          data: {}
        }
      end
    end
  end
end
