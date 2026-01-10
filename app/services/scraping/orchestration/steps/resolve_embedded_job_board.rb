# frozen_string_literal: true

require "uri"

module Scraping
  module Orchestration
    module Steps
      # Attempts to resolve embedded job board pages into a fetchable HTML document
      # that actually contains job content.
      #
      # Today this primarily targets Greenhouse "gh_jid" embeds used by many marketing sites
      # (WordPress, Webflow, etc.) where the visible page is a shell and the job content
      # is served from `job-boards.greenhouse.io`.
      class ResolveEmbeddedJobBoard < BaseStep
        GREENHOUSE_FOR_REGEX = %r{embed/job_board/js\?for=([a-zA-Z0-9_-]+)}.freeze

        def call(context)
          return continue unless context.board_type.to_s == "greenhouse"

          jid = extract_query_param(context.job_listing.url, "gh_jid")
          return continue unless jid.present?

          for_key = extract_greenhouse_for_key(context.html_content)
          return continue unless for_key.present?

          # Enable downstream API extraction (Greenhouse boards API) even for marketing URLs.
          context.company_slug ||= for_key
          context.job_id ||= jid

          embed_url = build_greenhouse_embed_url(for_key: for_key, jid: jid, source: extract_query_param(context.job_listing.url, "gh_src"))

          resolved = context.event_recorder.record(
            :embedded_job_board_fetch,
            input: {
              board_type: "greenhouse",
              for_key: for_key,
              gh_jid: jid,
              embed_url: embed_url
            }
          ) do |event|
            result = fetch_html(embed_url, context)
            event.set_output(
              success: result[:success],
              http_status: result[:http_status],
              html_size: result[:html_content]&.bytesize,
              cleaned_html_size: result[:cleaned_html]&.bytesize,
              cleaned_text_length: extracted_text_length(result[:cleaned_html]),
              error: result[:error],
              fetch_mode: "greenhouse_embed"
            )
            result
          end

          return continue unless resolved[:success]

          # Only switch if we clearly got "real" content (avoid swapping in another shell).
          cleaned_text_length = extracted_text_length(resolved[:cleaned_html])
          return continue if cleaned_text_length < 800

          context.html_content = resolved[:html_content]
          context.cleaned_html = resolved[:cleaned_html]
          context.fetch_mode = "greenhouse_embed"

          continue
        rescue => e
          context.event_recorder.record_simple(
            :embedded_job_board_fetch,
            status: :failed,
            output: { error: e.message, error_type: e.class.name }
          )
          continue
        end

        private

        def extract_greenhouse_for_key(html_content)
          html_content.to_s[GREENHOUSE_FOR_REGEX, 1]
        end

        def build_greenhouse_embed_url(for_key:, jid:, source: nil)
          query = { "for" => for_key, "gh_jid" => jid }
          query["gh_src"] = source if source.present?
          "https://job-boards.greenhouse.io/embed/job_board?#{URI.encode_www_form(query)}"
        end

        def extract_query_param(url, key)
          uri = URI.parse(url)
          query = uri.query.to_s
          Rack::Utils.parse_query(query)[key]
        rescue
          nil
        end

        def fetch_html(url, context)
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          response = HTTParty.get(
            url,
            headers: {
              "User-Agent" => Scraping::RenderedHtmlFetcherService::REALISTIC_UA,
              "Accept" => "text/html",
              "Accept-Language" => "en-US,en;q=0.9"
            },
            timeout: 30,
            open_timeout: 10,
            follow_redirects: true,
            max_redirects: 3
          )
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

          unless response.success?
            return { success: false, error: "HTTP #{response.code}: Failed to fetch embedded HTML", http_status: response.code }
          end

          html = response.body.to_s
          cleaner = Scraping::HtmlCleaners::CleanerFactory.cleaner_for_url(url)
          cleaned_html = cleaner.clean(html)

          ScrapedJobListingData.create_with_html(
            url: url,
            html_content: html,
            job_listing: context.job_listing,
            scraping_attempt: context.attempt,
            http_status: response.code,
            metadata: {
              fetched_via: "http",
              fetch_mode: "greenhouse_embed",
              rendered: false,
              duration_ms: duration_ms,
              embedded_from_url: context.job_listing.url
            }
          )

          {
            success: true,
            html_content: html,
            cleaned_html: cleaned_html,
            http_status: response.code,
            duration_ms: duration_ms
          }
        rescue Timeout::Error => e
          { success: false, error: "Embedded fetch timeout: #{e.message}" }
        rescue => e
          { success: false, error: "Embedded fetch failed: #{e.message}" }
        end

        def extracted_text_length(html)
          Nokogiri::HTML(html.to_s).text.to_s.strip.length
        rescue
          0
        end
      end
    end
  end
end
