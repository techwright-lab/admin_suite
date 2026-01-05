# frozen_string_literal: true

module InterviewPrep
  # Base class for LLM-backed prep generation with provider fallback and logging.
  class BaseGeneratorService
    # @param user [User]
    # @param interview_application [InterviewApplication]
    def initialize(user:, interview_application:)
      @user = user
      @application = interview_application
      @inputs_builder = InterviewPrep::InputsBuilderService.new(user: user, interview_application: interview_application)
    end

    # Generates and persists the artifact for this generator's kind.
    #
    # @return [InterviewPrepArtifact]
    def call
      artifact = find_or_build_artifact
      digest = inputs_builder.digest_for(kind)

      if artifact.status == "computed" && artifact.inputs_digest == digest
        return artifact
      end

      artifact.assign_attributes(status: :pending, inputs_digest: digest, error_message: nil)
      artifact.save!

      inputs = inputs_builder.build
      prompt = build_prompt(inputs)
      result = run_with_providers(prompt, inputs)

      if result[:success]
        artifact.assign_attributes(
          status: :computed,
          computed_at: Time.current,
          content: result[:content],
          provider: result[:provider],
          model: result[:model],
          llm_api_log_id: result[:llm_api_log_id]
        )
      else
        artifact.assign_attributes(
          status: :failed,
          computed_at: Time.current,
          error_message: result[:error].to_s,
          content: {}
        )
      end

      artifact.save!
      artifact
    end

    private

    attr_reader :user, :application, :inputs_builder

    # @return [Symbol]
    def kind
      raise NotImplementedError, "#{self.class} must implement #kind"
    end

    # @return [Ai::LlmPrompt, nil]
    def prompt_class
      raise NotImplementedError, "#{self.class} must implement #prompt_class"
    end

    # @return [String] operation_type for Ai::ApiLoggerService
    def operation_type
      "interview_prep_#{kind}"
    end

    def find_or_build_artifact
      InterviewPrepArtifact.find_or_initialize_by(interview_application: application, kind: kind).tap do |a|
        a.user ||= user
      end
    end

    def build_prompt(inputs)
      template_record = prompt_class.active_prompt
      vars = {
        candidate_profile: JSON.generate(inputs[:candidate_profile]),
        job_context: JSON.generate(inputs[:job_context]),
        interview_stage: inputs[:interview_stage].to_s,
        feedback_themes: JSON.generate(inputs[:feedback_themes])
      }

      return template_record.build_prompt(vars) if template_record

      # Fallback to code-defined default prompt (safe for new environments).
      prompt = prompt_class.default_prompt_template.dup
      vars.each { |k, v| prompt.gsub!("{{#{k}}}", v.to_s) }
      prompt
    end

    def provider_chain
      LlmProviders::ProviderConfigHelper.all_providers
    end

    def run_with_providers(prompt, inputs)
      template_record = prompt_class.active_prompt
      system_message =
        template_record&.system_prompt.presence ||
        (prompt_class.respond_to?(:default_system_prompt) ? prompt_class.default_system_prompt : nil)

      provider_chain.each do |provider_name|
        provider = provider_for(provider_name)
        next unless provider.available?

        response = provider.run(prompt, system_message: system_message)
        logger = Ai::ApiLoggerService.new(
          operation_type: operation_type,
          loggable: application,
          provider: provider_name,
          model: response[:model] || provider.model_name,
          llm_prompt: template_record
        )

        if response[:rate_limit]
          logger.record_result({ error: "rate_limited", rate_limit: true }, latency_ms: response[:latency_ms] || 0, prompt: prompt, content_size: prompt.bytesize)
          next
        end

        if response[:error]
          logger.record_result({ error: response[:error], error_type: response[:error_type] }, latency_ms: response[:latency_ms] || 0, prompt: prompt, content_size: prompt.bytesize)
          next
        end

        parsed = parse_json(response[:content])
        normalized = normalize_parsed(parsed)
        loggable_result = normalized.merge(
          raw_response: response[:content],
          input_tokens: response[:input_tokens],
          output_tokens: response[:output_tokens],
          extracted_fields: normalized.keys.map(&:to_s)
        )

        log = logger.record_result(
          loggable_result,
          latency_ms: response[:latency_ms] || 0,
          prompt: prompt,
          content_size: prompt.bytesize
        )

        return { success: true, content: normalized, provider: provider_name, model: response[:model], llm_api_log_id: log.id }
      rescue StandardError => e
        Rails.logger.warn("#{self.class} provider #{provider_name} failed: #{e.message}")
        next
      end

      { success: false, error: "All providers failed" }
    end

    def provider_for(provider_name)
      case provider_name.to_s.downcase
      when "openai" then LlmProviders::OpenaiProvider.new
      when "anthropic" then LlmProviders::AnthropicProvider.new
      when "ollama" then LlmProviders::OllamaProvider.new
      else
        raise ArgumentError, "Unknown provider: #{provider_name}"
      end
    end

    def parse_json(text)
      json_match = text.to_s.match(/\{.*\}/m)
      raise "No JSON found" unless json_match

      JSON.parse(json_match[0])
    end

    # Subclasses can override to enforce schema/shape.
    def normalize_parsed(parsed)
      parsed.is_a?(Hash) ? parsed : {}
    end
  end
end
