# frozen_string_literal: true

module Assistant
  module Memory
    # Proposes long-term memory items for user confirmation.
    #
    # Always user-confirmed: this service only creates MemoryProposal records.
    class MemoryProposer
      def initialize(user:, thread:, trace_id:)
        @user = user
        @thread = thread
        @trace_id = trace_id
      end

      def propose!
        return nil if recent_pending_proposal?

        messages = thread.messages.order(created_at: :desc).limit(20).pluck(:role, :content).reverse
        prompt = build_prompt(messages)

        llm_log = run_llm(prompt)
        return nil if llm_log.nil?

        items = parse_items(llm_log.response_text)
        return nil if items.empty?

        Assistant::Memory::MemoryProposal.create!(
          thread: thread,
          user: user,
          trace_id: trace_id,
          proposed_items: items,
          status: "pending",
          llm_api_log: llm_log
        )
      end

      private

      attr_reader :user, :thread, :trace_id

      def recent_pending_proposal?
        Assistant::Memory::MemoryProposal.where(user: user, thread: thread, status: "pending").where("created_at > ?", 12.hours.ago).exists?
      end

      def build_prompt(messages)
        prompt_template = Ai::AssistantMemoryProposalPrompt.active_prompt
        template = prompt_template&.prompt_template || Ai::AssistantMemoryProposalPrompt.default_prompt_template
        template.gsub("{{messages}}", messages.map { |r, c| "#{r.upcase}: #{c}" }.join("\n"))
      end

      def run_llm(prompt)
        provider_chain = LlmProviders::ProviderConfigHelper.all_providers

        provider_chain.each do |provider_name|
          provider = provider_for(provider_name)
          next unless provider&.available?

          system_message = <<~SYS
            Return only valid JSON. Do not include markdown or extra commentary.
          SYS

          logger = Ai::ApiLoggerService.new(
            operation_type: :assistant_chat,
            loggable: user,
            provider: provider.provider_name,
            model: provider.model_name,
            llm_prompt: Ai::AssistantMemoryProposalPrompt.active_prompt
          )

          result = logger.record(prompt: prompt, content_size: prompt.bytesize) do
            provider.run(prompt, system_message: system_message, temperature: 0.1, max_tokens: 800)
          end

          next if result[:error].present?
          return Ai::LlmApiLog.find(result[:llm_api_log_id])
        end

        nil
      end

      def parse_items(text)
        json = text.to_s.strip
        match = json.match(/\{.*\}/m)
        json = match[0] if match
        data = JSON.parse(json)
        items = Array(data["items"])

        items.filter_map do |item|
          next unless item.is_a?(Hash)
          key = item["key"].to_s
          next if key.blank?
          {
            "key" => key,
            "value" => item["value"].is_a?(Hash) ? item["value"] : { "value" => item["value"] },
            "reason" => item["reason"].to_s,
            "confidence" => item["confidence"].to_f
          }
        end
      rescue JSON::ParserError
        []
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
