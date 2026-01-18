# frozen_string_literal: true

module InterviewPrep
  # Base class for LLM-backed prep generation with provider fallback and logging.
  class BaseGeneratorService < ApplicationService
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
      result = run_with_providers(prompt)

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
      vars = {
        candidate_profile: JSON.generate(inputs[:candidate_profile]),
        job_context: JSON.generate(inputs[:job_context]),
        interview_stage: inputs[:interview_stage].to_s,
        feedback_themes: JSON.generate(inputs[:feedback_themes])
      }

      Ai::PromptBuilderService.new(
        prompt_class: prompt_class,
        variables: vars
      ).run
    end

    def provider_chain
      LlmProviders::ProviderConfigHelper.all_providers
    end

    def run_with_providers(prompt)
      template_record = prompt_class.active_prompt
      system_message =
        template_record&.system_prompt.presence ||
        (prompt_class.respond_to?(:default_system_prompt) ? prompt_class.default_system_prompt : nil)

      runner = Ai::ProviderRunnerService.new(
        provider_chain: provider_chain,
        prompt: prompt,
        content_size: prompt.bytesize,
        system_message: system_message,
        provider_for: method(:provider_for),
        logger_builder: lambda { |provider_name, provider|
          Ai::ApiLoggerService.new(
            operation_type: operation_type,
            loggable: application,
            provider: provider_name,
            model: provider.respond_to?(:model_name) ? provider.model_name : "unknown",
            llm_prompt: template_record
          )
        },
        operation: operation_type,
        loggable: application,
        user: user,
        error_context: {
          severity: "warning",
          application_id: application&.id
        }
      )

      result = runner.run do |response|
        parsed = parse_json(response[:content])
        normalized = normalize_parsed(parsed)
        log_data = normalized.merge(
          extracted_fields: normalized.keys.map(&:to_s)
        )
        [ normalized, log_data, true ]
      end

      return { success: false, error: result[:error] } unless result[:success]

      {
        success: true,
        content: result[:parsed],
        provider: result[:provider],
        model: result[:model],
        llm_api_log_id: result[:llm_api_log_id]
      }
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
      parsed = Ai::ResponseParserService.new(text).parse
      raise "No JSON found" unless parsed

      parsed
    end

    # Subclasses can override to enforce schema/shape.
    def normalize_parsed(parsed)
      parsed.is_a?(Hash) ? parsed : {}
    end
  end
end
