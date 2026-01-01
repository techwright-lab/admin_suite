# frozen_string_literal: true

module Admin
  module Portals
    # AI Portal
    #
    # Contains resources for AI and Assistant operations including:
    # - Assistant threads and conversations
    # - Tool executions and management
    # - User memories and proposals
    # - LLM configuration and logs
    class AiPortal < Admin::Base::Portal
      name "AI"
      icon :sparkles
      path_prefix "/admin/ai"

      section :dashboard do
        label "Dashboard"
        icon :chart_bar
        resources :dashboard
      end

      section :assistant do
        label "Assistant"
        icon :chat
        resources :assistant_threads, :assistant_turns, :assistant_events,
                  :assistant_tools, :assistant_tool_executions
      end

      section :memory do
        label "Memory"
        icon :brain
        resources :assistant_user_memories, :assistant_memory_proposals, :assistant_thread_summaries
      end

      section :llm do
        label "LLM"
        icon :cpu
        resources :llm_prompts, :llm_provider_configs, :llm_api_logs
      end
    end
  end
end
