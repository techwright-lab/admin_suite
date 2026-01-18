# frozen_string_literal: true

module InterviewRoundPrep
  # Orchestrates round-specific interview prep generation using LLM providers.
  #
  # Builds comprehensive prep content including:
  # - Round summary and format hints
  # - Expected questions tailored to round type
  # - Historical performance analysis
  # - Company-specific patterns
  # - Preparation checklist
  #
  # @example
  #   service = InterviewRoundPrep::GenerateService.new(interview_round: round)
  #   artifact = service.call
  class GenerateService < ApplicationService
    # @param interview_round [InterviewRound]
    # @param force [Boolean] Force regeneration even if artifact exists
    def initialize(interview_round:, force: false)
      @round = interview_round
      @force = force
      @inputs_builder = InputsBuilderService.new(interview_round: round)
    end

    # Generates and persists the prep artifact.
    #
    # @return [InterviewRoundPrepArtifact]
    def call
      artifact = find_or_build_artifact
      digest = inputs_builder.digest_for(:comprehensive)

      # Return cached if valid and not forcing regeneration
      if !force && artifact.persisted? && artifact.completed? && artifact.inputs_digest == digest
        return artifact
      end

      # Mark as generating
      artifact.assign_attributes(status: :generating, inputs_digest: digest)
      artifact.save!

      # Build inputs and generate
      inputs = inputs_builder.build
      prompt = build_prompt(inputs)
      result = run_with_providers(prompt)

      if result[:success]
        artifact.complete!(result[:content], digest: digest)
      else
        artifact.fail!(result[:error])
      end

      artifact
    end

    private

    attr_reader :round, :force, :inputs_builder

    # @return [InterviewRoundPrepArtifact]
    def find_or_build_artifact
      InterviewRoundPrepArtifact.find_or_initialize_for(
        interview_round: round,
        kind: :comprehensive
      )
    end

    # @return [Ai::RoundPrepPrompt, nil]
    def prompt_class
      Ai::RoundPrepPrompt
    end

    # @return [String]
    def operation_type
      "round_prep_comprehensive"
    end

    # @return [String]
    def build_prompt(inputs)
      vars = {
        round_context: JSON.pretty_generate(inputs[:round_context]),
        job_context: JSON.pretty_generate(inputs[:job_context]),
        candidate_profile: JSON.pretty_generate(inputs[:candidate_profile]),
        historical_performance: JSON.pretty_generate(inputs[:historical_performance]),
        company_patterns: JSON.pretty_generate(inputs[:company_patterns])
      }

      Ai::PromptBuilderService.new(
        prompt_class: prompt_class,
        variables: vars
      ).run
    end

    # @return [Array<String>]
    def provider_chain
      LlmProviders::ProviderConfigHelper.all_providers
    end

    # @return [Hash]
    def run_with_providers(prompt)
      template_record = prompt_class.active_prompt
      system_message = template_record&.system_prompt.presence ||
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
            loggable: round,
            provider: provider_name,
            model: provider.respond_to?(:model_name) ? provider.model_name : "unknown",
            llm_prompt: template_record
          )
        },
        operation: operation_type,
        loggable: round,
        user: round.interview_application&.user,
        error_context: {
          severity: "warning",
          interview_round_id: round&.id
        }
      )

      result = runner.run do |response|
        parsed = parse_json(response[:content])
        normalized = normalize_content(parsed)
        [ normalized, normalized, true ]
      end

      return { success: false, error: result[:error] } unless result[:success]

      {
        success: true,
        content: result[:parsed],
        provider: result[:provider],
        model: result[:model]
      }
    end

    # @return [LlmProviders::BaseProvider]
    def provider_for(provider_name)
      case provider_name.to_s.downcase
      when "openai" then LlmProviders::OpenaiProvider.new
      when "anthropic" then LlmProviders::AnthropicProvider.new
      when "ollama" then LlmProviders::OllamaProvider.new
      else
        raise ArgumentError, "Unknown provider: #{provider_name}"
      end
    end

    # @return [Hash]
    def parse_json(text)
      parsed = Ai::ResponseParserService.new(text).parse
      raise "No JSON found in response" unless parsed

      parsed
    end

    # Normalizes the parsed content to expected schema
    #
    # @return [Hash]
    def normalize_content(parsed)
      return {} unless parsed.is_a?(Hash)

      {
        round_summary: parsed["round_summary"],
        expected_questions: Array(parsed["expected_questions"]),
        your_history: parsed["your_history"],
        company_patterns: parsed["company_patterns"],
        preparation_checklist: Array(parsed["preparation_checklist"]),
        answer_strategies: Array(parsed["answer_strategies"]),
        tips: Array(parsed["tips"])
      }.compact
    end
  end
end
