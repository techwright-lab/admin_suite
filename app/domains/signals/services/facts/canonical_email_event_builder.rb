# frozen_string_literal: true

module Signals
  module Facts
    # Builds the canonical email event payload for DecisionInput.
    #
    # Goal: ensure every downstream component (facts extraction, planner, semantic validation)
    # sees the *same* canonical email text.
    class CanonicalEmailEventBuilder
      REPLY_SEPARATORS = [
        /^On .+ wrote:$/i,
        /^On .+sent:$/i,
        /^On .+wrote$/i,
        /^From:\s+/i,
        /^Sent:\s+/i,
        /^To:\s+/i,
        /^Subject:\s+/i,
        /^-----Original Message-----/i,
        /^----- Forwarded message -----/i,
        /^Begin forwarded message:/i
      ].freeze

      URL_REGEX = %r{https?://[^\s<>"')]+}i

      def initialize(synced_email)
        @synced_email = synced_email
      end

      def build
        raw_text, source = best_body_source
        canonical = canonicalize_text(raw_text)
        links = extract_links(canonical)

        {
          "event_type" => "email",
          "synced_email_id" => synced_email.id,
          "thread_id" => synced_email.thread_id,
          "received_at" => synced_email.email_date&.iso8601,
          "email_date" => synced_email.email_date&.iso8601,
          "from" => {
            "email" => synced_email.from_email,
            "name" => synced_email.from_name
          },
          "to" => [],
          "subject" => synced_email.subject,
          "body" => {
            "text" => canonical,
            "source" => source,
            "truncated" => false,
            "normalization" => {
              "replies_removed" => true,
              "html_stripped" => source == "body_html",
              "whitespace_collapsed" => true
            }
          },
          "links" => links
        }
      end

      private

      attr_reader :synced_email

      def best_body_source
        if synced_email.body_preview.present?
          [ synced_email.body_preview.to_s, "body_preview" ]
        elsif synced_email.body_html.present?
          [ ActionController::Base.helpers.strip_tags(synced_email.body_html.to_s), "body_html" ]
        else
          [ synced_email.snippet.to_s, "snippet" ]
        end
      end

      def canonicalize_text(text)
        return "" if text.blank?

        normalized = text.to_s.gsub(/\r\n?/, "\n")
        lines = normalized.split("\n")
        cutoff = lines.index { |line| REPLY_SEPARATORS.any? { |rx| line.to_s.strip.match?(rx) } }
        kept = cutoff ? lines[0...cutoff] : lines
        kept = kept.reject { |line| line.lstrip.start_with?(">") }
        kept.join("\n").gsub(/\s+/, " ").strip
      end

      def extract_links(text)
        text.to_s.scan(URL_REGEX).uniq.first(50).map do |url|
          { "url" => url, "label_hint" => nil }
        end
      end
    end
  end
end
