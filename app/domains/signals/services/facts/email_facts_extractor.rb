# frozen_string_literal: true

module Signals
  module Facts
    # Extracts EmailFacts using an LLM and validates against the EmailFacts schema.
    #
    # Persists results onto synced_email.extracted_data under versioned keys.
    class EmailFactsExtractor < ApplicationService
      EMAIL_FACTS_SCHEMA_ID = "gleania://signals/contracts/schemas/components/facts/email_facts.schema.json"
      OPERATION_TYPE = :email_facts_extraction

      FACTS_KEY = "email_facts_v1"
      FACTS_META_KEY = "email_facts_meta_v1"

      def initialize(synced_email, decision_input_base:)
        @synced_email = synced_email
        @decision_input_base = decision_input_base
      end

      def call
        log_info("EmailFacts extraction start: synced_email_id=#{synced_email.id}")

        prompt = build_prompt
        prompt_template = Ai::EmailFactsExtractionPrompt.active_prompt
        system_message = prompt_template&.system_prompt.presence || Ai::EmailFactsExtractionPrompt.default_system_prompt

        runner = Ai::ProviderRunnerService.new(
          provider_chain: provider_chain,
          prompt: prompt,
          content_size: prompt.bytesize,
          system_message: system_message,
          provider_for: method(:get_provider_instance),
          run_options: { max_tokens: 2500, temperature: 0.1 },
          logger_builder: lambda { |provider_name, provider|
            Ai::ApiLoggerService.new(
              operation_type: OPERATION_TYPE,
              loggable: synced_email,
              provider: provider_name,
              model: provider.respond_to?(:model_name) ? provider.model_name : "unknown",
              llm_prompt: prompt_template
            )
          },
          operation: OPERATION_TYPE,
          loggable: synced_email,
          user: synced_email&.user,
          error_context: {
            severity: "warning",
            synced_email_id: synced_email.id,
            application_id: synced_email.interview_application_id
          }
        )

        result = runner.run do |response|
          parsed = parse_response(response[:content]) || {}
          schema_errors = schema_validator.errors_for(parsed)

          # We accept only if schema-valid.
          accept = schema_errors.empty?
          log_data = {
            schema_valid: accept,
            schema_error_count: schema_errors.size,
            classification_kind: parsed.dig("classification", "kind"),
            confidence: parsed.dig("extraction", "confidence")
          }.compact
          [ parsed, log_data, accept ]
        end

        unless result[:success]
          log_warning("EmailFacts extraction failed: synced_email_id=#{synced_email.id} error=#{result[:error]}")
          persist_meta(status: "failed", errors: [ { "message" => result[:error] } ])
          return { success: false, error: result[:error] }
        end

        facts = result[:parsed]
        persist_facts!(
          facts,
          meta: {
            "status" => "ok",
            "provider" => result[:provider],
            "model" => result[:model],
            "llm_api_log_id" => result[:llm_api_log_id],
            "latency_ms" => result[:latency_ms],
            "generated_at" => Time.current.iso8601
          }
        )

        log_info("EmailFacts extraction ok: synced_email_id=#{synced_email.id} kind=#{facts.dig("classification", "kind")}")
        { success: true, facts: facts, llm_api_log_id: result[:llm_api_log_id] }
      rescue StandardError => e
        notify_error(
          e,
          context: "signals_email_facts_extractor",
          severity: "warning",
          user: synced_email&.user,
          synced_email_id: synced_email&.id,
          application_id: synced_email&.interview_application_id
        )
        log_error("EmailFacts extraction exception: synced_email_id=#{synced_email&.id} #{e.class}: #{e.message}")
        persist_meta(status: "exception", errors: [ { "message" => e.message, "class" => e.class.name } ])
        { success: false, error: e.message }
      end

      private

      attr_reader :synced_email, :decision_input_base

      def schema_validator
        @schema_validator ||= Signals::Contracts::Validators::JsonSchemaValidator.new(schema_id: EMAIL_FACTS_SCHEMA_ID)
      end

      def build_prompt
        event = decision_input_base.fetch("event")
        app_snapshot = decision_input_base["application"]
        vars = {
          subject: event["subject"].to_s,
          body: event.dig("body", "text").to_s,
          from_email: event.dig("from", "email").to_s,
          from_name: event.dig("from", "name").to_s,
          email_type: synced_email.email_type.to_s,
          application_snapshot: app_snapshot ? JSON.pretty_generate(app_snapshot) : "null"
        }

        Ai::PromptBuilderService.new(
          prompt_class: Ai::EmailFactsExtractionPrompt,
          variables: vars
        ).run
      end

      def parse_response(content)
        Ai::ResponseParserService.new(content).parse(symbolize: false)
      end

      def provider_chain
        LlmProviders::ProviderConfigHelper.all_providers
      end

      def get_provider_instance(provider_name)
        case provider_name.to_s.downcase
        when "openai" then LlmProviders::OpenaiProvider.new
        when "anthropic" then LlmProviders::AnthropicProvider.new
        when "ollama" then LlmProviders::OllamaProvider.new
        else nil
        end
      end

      def persist_meta(status:, errors:)
        persist_facts!(nil, meta: { "status" => status, "errors" => errors, "generated_at" => Time.current.iso8601 })
      end

      def persist_facts!(facts, meta:)
        existing = synced_email.extracted_data.is_a?(Hash) ? synced_email.extracted_data.deep_dup : {}
        existing[FACTS_KEY] = facts
        existing[FACTS_META_KEY] = meta
        synced_email.update!(extracted_data: existing)
      end
    end
  end
end
