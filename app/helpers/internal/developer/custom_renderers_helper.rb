# frozen_string_literal: true

module Internal
  module Developer
    # App-specific renderers for the internal developer portal.
    #
    # These are intentionally kept out of the core admin suite helper so the
    # suite can be extracted into a reusable engine/gem.
    module CustomRenderersHelper
      # Renders a billing debug snapshot for a user record.
      #
      # Intended for the internal developer portal.
      #
      # @param resource [ActiveRecord::Base] Expected to be a User
      # @return [String]
      def render_billing_debug_snapshot(resource)
        unless resource.is_a?(User)
          return content_tag(:p, "Billing debug snapshot is only supported for User records.", class: "text-slate-500 italic text-sm")
        end

        snapshot = Billing::DebugSnapshotService.new(user: resource).run
        render_json_block(snapshot)
      rescue StandardError => e
        content_tag(:div, class: "bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-4") do
          concat(content_tag(:p, "Failed to build billing debug snapshot.", class: "text-sm font-medium text-red-700 dark:text-red-300"))
          concat(content_tag(:p, e.message.to_s, class: "mt-1 text-sm text-red-600 dark:text-red-400 font-mono"))
        end
      end

      # Renders provider-native payloads for Ai::LlmApiLog in a prominent, copy-friendly format.
      #
      # Reads from:
      # - request_payload["provider_request"]
      # - response_payload["provider_response"] / ["provider_error_response"]
      #
      # @param resource [ActiveRecord::Base]
      # @param kind [Symbol] :provider_request, :provider_response, :provider_error_response
      # @return [String]
      def render_llm_provider_payload(resource, kind:)
        return content_tag(:p, "Not available", class: "text-slate-400 italic text-sm") unless resource.respond_to?(:request_payload) && resource.respond_to?(:response_payload)

        request_payload = resource.request_payload || {}
        response_payload = resource.response_payload || {}

        value =
          case kind.to_sym
          when :provider_request
            request_payload["provider_request"] || request_payload[:provider_request]
          when :provider_response
            response_payload["provider_response"] || response_payload[:provider_response]
          when :provider_error_response
            response_payload["provider_error_response"] || response_payload[:provider_error_response]
          else
            nil
          end

        if value.blank?
          hint =
            if kind.to_sym == :provider_error_response
              "No provider error response captured."
            else
              "No provider payload captured."
            end
          return content_tag(:div, class: "text-sm text-slate-500 dark:text-slate-400") do
            concat(content_tag(:p, hint, class: "italic"))
            concat(content_tag(:p, "Older logs (or synthetic logs) may not include raw provider payloads.", class: "text-xs mt-1"))
          end
        end

        # Render hashes/arrays as highlighted JSON. Strings are attempted as JSON, else plain.
        if value.is_a?(Hash) || value.is_a?(Array)
          render_json_block(value)
        else
          str = value.to_s
          if str.strip.start_with?("{", "[")
            begin
              render_json_block(JSON.parse(str))
            rescue JSON::ParserError
              render_text_block(str)
            end
          else
            render_text_block(str)
          end
        end
      end
    end
  end
end
