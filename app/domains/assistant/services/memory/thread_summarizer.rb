# frozen_string_literal: true

module Assistant
  module Memory
    # Produces/updates a rolling summary for a thread to bound prompt size.
    class ThreadSummarizer
      SUMMARY_EVERY_N_MESSAGES = 20

      def initialize(thread:)
        @thread = thread
      end

      def maybe_summarize!
        summary = thread.summary || thread.build_summary
        last_id = summary.last_summarized_message_id

        scope = thread.messages.order(:id)
        scope = scope.where("id > ?", last_id) if last_id.present?
        new_count = scope.count

        return nil if new_count < SUMMARY_EVERY_N_MESSAGES

        messages = scope.limit(60).pluck(:role, :content)
        prompt = build_prompt(existing_summary: summary.summary_text, messages: messages)

        llm_log = run_llm(prompt)
        return nil if llm_log.nil?

        new_summary_text = parse_summary(llm_log.response_text)

        summary.update!(
          summary_text: new_summary_text,
          summary_version: summary.summary_version.to_i + 1,
          last_summarized_message_id: scope.maximum(:id),
          llm_api_log: llm_log
        )

        summary
      end

      private

      attr_reader :thread

      def build_prompt(existing_summary:, messages:)
        prompt_template = Ai::AssistantThreadSummaryPrompt.active_prompt
        template = prompt_template&.prompt_template || Ai::AssistantThreadSummaryPrompt.default_prompt_template

        template
          .gsub("{{existing_summary}}", existing_summary.to_s)
          .gsub("{{messages}}", messages.map { |r, c| "#{r.upcase}: #{c}" }.join("\n"))
      end

      def run_llm(prompt)
        provider_chain = LlmProviders::ProviderConfigHelper.all_providers

        provider_chain.each do |provider_name|
          provider = provider_for(provider_name)
          next unless provider&.available?

          system_message = "Return only the updated summary text."

          logger = Ai::ApiLoggerService.new(
            operation_type: :assistant_chat,
            loggable: thread,
            provider: provider.provider_name,
            model: provider.model_name,
            llm_prompt: Ai::AssistantThreadSummaryPrompt.active_prompt
          )

          result = logger.record(prompt: prompt, content_size: prompt.bytesize) do
            provider.run(prompt, system_message: system_message, temperature: 0.1, max_tokens: 600)
          end

          next if result[:error].present?
          return Ai::LlmApiLog.find(result[:llm_api_log_id])
        end

        nil
      end

      def parse_summary(text)
        text.to_s.strip
      end

      def provider_for(provider_name)
        case provider_name.to_s.downcase
        when "openai" then LlmProviders::OpenaiProvider.new
        when "anthropic" then LlmProviders::AnthropicProvider.new
        when "ollama" then LlmProviders::OllamaProvider.new
        else nil
        end
      end
    end
  end
end
