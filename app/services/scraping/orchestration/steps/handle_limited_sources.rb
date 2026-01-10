# frozen_string_literal: true

module Scraping
  module Orchestration
    module Steps
      # Handles job boards with limited extraction capability
      #
      # For sources like LinkedIn, Indeed, Glassdoor that require authentication
      # or heavily block scraping, this step extracts what's publicly available
      # (mainly meta tags) and marks the extraction as limited.
      class HandleLimitedSources < BaseStep
        LIMITED_BOARDS = %i[linkedin indeed glassdoor].freeze

        def call(context)
          return continue unless limited_board?(context)

          context.event_recorder.record(
            :limited_source_handling,
            input: { board_type: context.board_type, url: context.job_listing.url }
          ) do |event|
            result = extract_meta_tags(context)
            context.limited_extraction = true

            # Update job listing with limited data
            if result.any?
              update_job_listing(context, result)
              event.set_output(
                extracted_fields: result.keys,
                extraction_quality: "limited",
                title: result[:title],
                company: result[:company],
                description_preview: result[:description]&.truncate(100)
              )
            else
              event.set_output(
                extracted_fields: [],
                extraction_quality: "limited",
                reason: "No meta tags found"
              )
            end

            result
          end

          # For LinkedIn, we still try full scraping but with lower expectations
          # The AI extraction step will handle whatever HTML we can get
          continue
        end

        private

        def limited_board?(context)
          LIMITED_BOARDS.include?(context.board_type)
        end

        # Extracts information from meta tags (og:*, twitter:*, etc.)
        # @return [Hash] Extracted data
        def extract_meta_tags(context)
          return {} if context.html_content.blank?

          doc = Nokogiri::HTML(context.html_content)
          result = {}

          # Open Graph tags
          og_title = doc.at('meta[property="og:title"]')&.[]("content")
          og_description = doc.at('meta[property="og:description"]')&.[]("content")
          og_image = doc.at('meta[property="og:image"]')&.[]("content")
          og_site_name = doc.at('meta[property="og:site_name"]')&.[]("content")

          # Twitter cards
          twitter_title = doc.at('meta[name="twitter:title"]')&.[]("content")
          twitter_description = doc.at('meta[name="twitter:description"]')&.[]("content")

          # Standard meta tags
          meta_title = doc.at("title")&.text
          meta_description = doc.at('meta[name="description"]')&.[]("content")

          # LinkedIn specific - they often have schema.org data
          schema_data = extract_schema_org(doc)

          # Build result with best available data
          result[:title] = parse_linkedin_title(og_title || twitter_title || meta_title || schema_data[:title])
          result[:company] = og_site_name || schema_data[:company]
          result[:description] = og_description || twitter_description || meta_description || schema_data[:description]
          result[:logo_url] = og_image if og_image&.include?("logo")
          result[:location] = schema_data[:location]

          result.compact
        end

        # Parses LinkedIn title which often includes " | Company" suffix
        def parse_linkedin_title(title)
          return nil if title.blank?

          # Remove " | LinkedIn" suffix
          title = title.gsub(/\s*\|\s*LinkedIn\s*$/i, "")

          # Split on " at " or " - " to separate title from company
          if title.include?(" at ")
            title.split(" at ").first&.strip
          elsif title.include?(" - ")
            title.split(" - ").first&.strip
          else
            title.strip
          end
        end

        # Extracts data from JSON-LD schema.org markup
        def extract_schema_org(doc)
          result = {}

          doc.css('script[type="application/ld+json"]').each do |script|
            data = JSON.parse(script.text) rescue nil
            next unless data

            # Handle arrays of schemas
            schemas = data.is_a?(Array) ? data : [ data ]

            schemas.each do |schema|
              next unless schema.is_a?(Hash)

              if schema["@type"] == "JobPosting"
                result[:title] ||= schema["title"]
                result[:description] ||= schema["description"]
                result[:company] ||= schema.dig("hiringOrganization", "name")
                result[:location] ||= schema.dig("jobLocation", "address", "addressLocality")
                result[:salary_min] ||= schema.dig("baseSalary", "value", "minValue")
                result[:salary_max] ||= schema.dig("baseSalary", "value", "maxValue")
              end
            end
          end

          result
        end

        def update_job_listing(context, result)
          job_listing = context.job_listing
          updates = {}

          updates[:title] = result[:title] if result[:title].present? && job_listing.title.blank?

          # Store extraction metadata
          scraped_data = job_listing.scraped_data || {}
          scraped_data["job_board"] = context.board_type.to_s
          scraped_data["extraction_quality"] = "limited"
          scraped_data["limited_extraction_reason"] = limited_extraction_reason(context.board_type)
          scraped_data["meta_extraction"] = result

          updates[:scraped_data] = scraped_data

          job_listing.update!(updates) if updates.any?

          # Try to find/create company if we have a name and current company is placeholder
          if result[:company].present? && placeholder_company?(job_listing.company)
            company = Company.find_or_create_by!(name: result[:company])
            job_listing.update!(company: company)
          end
        end

        def placeholder_company?(company)
          return true if company.nil?

          placeholder_names = [ "unknown company", "unknown" ]
          placeholder_names.include?(company.name.to_s.downcase)
        end

        def limited_extraction_reason(board_type)
          case board_type
          when :linkedin
            "LinkedIn requires authentication for full job details"
          when :indeed
            "Indeed limits public access to job content"
          when :glassdoor
            "Glassdoor requires authentication for full job details"
          else
            "Source has limited public access"
          end
        end
      end
    end
  end
end
