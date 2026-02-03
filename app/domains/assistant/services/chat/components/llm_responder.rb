# frozen_string_literal: true

module Assistant
  module Chat
    module Components
      class LlmResponder
        def initialize(user:, trace_id:, question:, context:, allowed_tools:, thread: nil, media: nil)
          @user = user
          @trace_id = trace_id
          @question = question.to_s
          @context = context
          @allowed_tools = allowed_tools
          @thread = thread
          @media = Array(media).compact
        end

        def call
          system_prompt = build_system_prompt_with_context
          provider_chain = LlmProviders::ProviderConfigHelper.all_providers

          last_error = nil
          last_failure = nil
          provider_chain.each do |provider_name|
            res = attempt_provider(provider_name: provider_name, system_prompt: system_prompt)
            if res[:status] == "success"
              return res
            end

            last_error = res[:error].presence || last_error
            last_failure = res if res[:status] == "error"
          end

          build_fallback_error(
            provider_chain: provider_chain,
            system_prompt: system_prompt,
            last_error: last_error,
            last_failure: last_failure
          )
        end

        private

        attr_reader :user, :trace_id, :question, :context, :allowed_tools, :thread, :media

        # Returns the system prompt for the assistant.
        # Uses system_prompt column from DB if available, falls back to default.
        # This follows the same pattern as extraction prompts.
        #
        # @return [String] System prompt for the LLM
        def active_system_prompt
          Ai::AssistantSystemPrompt.active_prompt&.system_prompt.presence ||
            Ai::AssistantSystemPrompt.default_system_prompt
        end

        # Builds the system prompt with injected context
        #
        # The context includes:
        # - User info (name, account age)
        # - Career context (resume summary, work history, targets)
        # - Skills summary
        # - Pipeline status
        # - Current page context
        def build_system_prompt_with_context
          base_prompt = active_system_prompt

          context_section = <<~CONTEXT

            ---

            USER CONTEXT:
            #{format_context_for_prompt}

            ---
          CONTEXT

          "#{base_prompt}\n#{context_section}"
        end

        # Formats the context hash into a readable section for the system prompt
        def format_context_for_prompt
          sections = []

          # User info
          if context[:user].present?
            sections << "User: #{context[:user][:name]}"
          end

          # Career context (tiered - most important for job search assistance)
          if context[:career].present?
            career = context[:career]

            if career[:resume].present?
              resume = career[:resume]
              sections << "\nProfile Summary: #{resume[:profile_summary]}" if resume[:profile_summary].present?
              sections << "Strengths: #{resume[:strengths].join(', ')}" if resume[:strengths].present?
              sections << "Domains: #{resume[:domains].join(', ')}" if resume[:domains].present?

              # Full resume text only included when page_context has include_full_resume or resume_id
              if resume[:full_text].present?
                sections << "\n--- Full Resume ---\n#{resume[:full_text]}\n--- End Resume ---"
              end
            end

            if career[:work_history].present?
              work_lines = career[:work_history].map do |exp|
                status = exp[:current] ? "(Current)" : ""
                dates = [ exp[:start_date], exp[:end_date] ].compact.join(" - ")
                skills = exp[:skills].present? ? "Skills: #{exp[:skills].join(', ')}" : nil
                highlights = exp[:highlights].present? ? "Highlights: #{exp[:highlights].join('; ')}" : nil
                [ "• #{exp[:title]} at #{exp[:company]} #{status} #{dates}", skills, highlights ].compact.join("\n  ")
              end
              sections << "\nWork History:\n#{work_lines.join("\n")}"
            end

            if career[:targets].present?
              targets = career[:targets]
              sections << "\nCareer Targets:" if targets.any?
              sections << "  Target Roles: #{targets[:roles].join(', ')}" if targets[:roles].present?
              sections << "  Target Companies: #{targets[:companies].join(', ')}" if targets[:companies].present?
              sections << "  Target Domains: #{targets[:domains].join(', ')}" if targets[:domains].present?
            end
          end

          # Top skills
          if context[:skills].present? && context[:skills][:top_skills].present?
            skills = context[:skills][:top_skills].map { |s| s[:name] }.compact.first(10)
            sections << "\nTop Skills: #{skills.join(', ')}" if skills.any?
          end

          # Pipeline status
          if context[:pipeline].present?
            pipeline = context[:pipeline]
            sections << "\nPipeline: #{pipeline[:interview_applications_count]} applications"
            if pipeline[:recent_interview_applications].present?
              recent = pipeline[:recent_interview_applications].first(3).map do |app|
                base = "#{app[:job_role]} at #{app[:company]} (#{app[:status]})"
                # Include identifiers so the model can reliably call tools.
                # Many tools accept application_uuid/application_id, and without these the model may hallucinate.
                ids = []
                ids << "id=#{app[:id]}" if app[:id].present?
                ids << "uuid=#{app[:uuid]}" if app[:uuid].present?
                ids.any? ? "#{base} [#{ids.join(' ')}]" : base
              end
              sections << "Recent: #{recent.join('; ')}"
            end
          end

          # Page context
          if context[:page].present? && context[:page].any?
            page_info = context[:page].map { |k, v| "#{k}: #{v}" }.join(", ")
            sections << "\nCurrent Page: #{page_info}"
          end

          sections.join("\n")
        end

        def attempt_provider(provider_name:, system_prompt:)
          provider = provider_for(provider_name)
          return { status: "skipped", error: nil } unless provider&.available?

          router = Assistant::Providers::ProviderRouter.new(
            thread: thread,
            question: question,
            system_prompt: system_prompt,
            allowed_tools: allowed_tools,
            media: media
          )

          logger = Ai::ApiLoggerService.new(
            operation_type: :assistant_chat,
            loggable: user,
            provider: provider.provider_name,
            model: provider.model_name,
            llm_prompt: Ai::AssistantSystemPrompt.active_prompt
          )

          request_for_log = router.request_payload_for_log(provider: provider)
          result = logger.record(prompt: request_for_log, content_size: request_for_log.bytesize) do
            router.call(provider: provider)
          end

          if result[:error].present?
            return {
              status: "error",
              error: result[:error],
              error_type: result[:error_type],
              provider: provider.provider_name,
              model: provider.model_name,
              llm_api_log_id: result[:llm_api_log_id]
            }
          end

          build_success_response(provider: provider, result: result)
        end

        def build_success_response(provider:, result:)
          tool_calls = normalize_and_validate_tool_calls(result[:tool_calls], provider: provider.provider_name)

          answer, pending_tool_followup = finalize_answer(
            answer: result[:content].to_s,
            tool_calls: tool_calls
          )

          {
            answer: answer,
            tool_calls: tool_calls,
            llm_api_log: Ai::LlmApiLog.find(result[:llm_api_log_id]),
            latency_ms: result[:latency_ms],
            status: "success",
            metadata: {
              trace_id: trace_id,
              provider: provider.provider_name,
              model: provider.model_name,
              tool_calls: tool_calls,
              provider_state: extract_provider_state(provider: provider.provider_name, result: result),
              provider_content_blocks: (provider.provider_name.to_s.downcase == "anthropic" ? result[:content_blocks] : nil),
              pending_tool_followup: pending_tool_followup
            }.compact
          }
        end

        def normalize_and_validate_tool_calls(raw_tool_calls, provider:)
          calls = Array(raw_tool_calls).map { |tc| normalize_tool_call(tc, provider: provider) }.compact

          calls.select do |tc|
            contract = Assistant::Contracts::ToolCallContract.call(tc)
            next true if contract.success?

            Rails.logger.warn("[LlmResponder] Dropping invalid tool_call: errors=#{contract.errors.to_h.inspect} tool_call=#{tc.inspect}")
            false
          end
        end

        def finalize_answer(answer:, tool_calls:)
          pending_tool_followup = pending_tool_followup?(tool_calls: tool_calls)

          if pending_tool_followup
            return [ "Working on it — I’m fetching the latest info now.", true ]
          end

          if answer.strip.blank? && tool_calls.any?
            answer = "I have some proposed actions for you to review below."
          end

          answer = "I couldn't generate a response. Please try again." if answer.strip.blank?

          [ answer, false ]
        end

        def pending_tool_followup?(tool_calls:)
          return false if tool_calls.blank?

          tool_calls.any? do |tc|
            tool = allowed_tools.find { |t| t.tool_key == tc[:tool_key] }
            next false if tool.nil?

            (tool.requires_confirmation || tool.risk_level != "read_only") == false
          end
        end

        def build_fallback_error(provider_chain:, system_prompt:, last_error:, last_failure:)
          error_message = last_error || "All providers failed"

          # Prefer the real provider attempt log (it has provider/model/error_type/raw_response)
          # so the turn links to the useful failure details.
          if last_failure&.dig(:llm_api_log_id).present?
            log = Ai::LlmApiLog.find(last_failure[:llm_api_log_id])
            return {
              answer: "Sorry — I ran into an issue generating a response. Please try again.",
              tool_calls: [],
              llm_api_log: log,
              latency_ms: nil,
              status: "error",
              metadata: {
                trace_id: trace_id,
                provider: last_failure[:provider] || log.provider || "unknown",
                model: last_failure[:model] || log.model || "unknown",
                error: error_message,
                error_type: last_failure[:error_type] || log.error_type
              }.compact
            }
          end

          # No provider attempt log exists (e.g., all providers were unavailable). Record a synthetic log.
          fallback_provider = provider_for(provider_chain.first)
          logger = Ai::ApiLoggerService.new(
            operation_type: :assistant_chat,
            loggable: user,
            provider: (fallback_provider&.provider_name || "unknown"),
            model: (fallback_provider&.model_name || "unknown"),
            llm_prompt: Ai::AssistantSystemPrompt.active_prompt
          )

          request_for_log = build_request_for_log(provider_name: (fallback_provider&.provider_name || "unknown"), system_prompt: system_prompt)
          failed = logger.record(prompt: request_for_log, content_size: request_for_log.bytesize) do
            { content: nil, input_tokens: nil, output_tokens: nil, confidence: nil, error: error_message, error_type: "all_providers_failed" }
          end

          {
            answer: "Sorry — I ran into an issue generating a response. Please try again.",
            tool_calls: [],
            llm_api_log: Ai::LlmApiLog.find(failed[:llm_api_log_id]),
            latency_ms: failed[:latency_ms],
            status: "error",
            metadata: {
              trace_id: trace_id,
              provider: (fallback_provider&.provider_name || "unknown"),
              model: (fallback_provider&.model_name || "unknown"),
              error: error_message,
              error_type: "all_providers_failed"
            }.compact
          }
        end

        def normalize_tool_call(tc, provider:)
          h = tc.is_a?(Hash) ? tc : {}
          tool_key = h[:tool_key] || h["tool_key"] || h[:name] || h["name"]
          args = h[:args] || h["args"] || h[:input] || h["input"] || {}
          tool_call_id = h[:id] || h["id"] || h[:call_id] || h["call_id"]
          return nil if tool_key.blank?

          {
            tool_key: tool_key.to_s,
            args: args.is_a?(Hash) ? args : {},
            provider_name: provider.to_s,
            provider_tool_call_id: tool_call_id.to_s.presence
          }.compact
        end

        def extract_provider_state(provider:, result:)
          case provider.to_s.downcase
          when "openai"
            { response_id: result[:response_id] || result["response_id"] }.compact
          when "anthropic"
            { message_id: result[:message_id] || result["message_id"] }.compact
          else
            {}
          end
        end

        def build_request_for_log(provider_name:, system_prompt:)
          # Used only for synthetic fallback logging paths. ProviderRouter is used for real provider attempts.
          {
            provider: provider_name,
            system: system_prompt.to_s,
            question: question.to_s,
            tools_count: allowed_tools.size
          }.to_json
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
end
