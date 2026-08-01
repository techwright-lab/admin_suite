# frozen_string_literal: true

module AdminSuite
  module Renderers
    # The four Gleania-specific LLM chat-transcript renderers, moved verbatim
    # out of `AdminSuite::BaseHelper` (role-coloured message bubbles, tool-call
    # panels, prompt-template mustache highlighting).
    #
    # These are deprecated: they still work in 0.4.0 (logging a warning once
    # per key per process the first time each is used), and are targeted for
    # DELETION in 0.6.0 (moved from the originally-planned 0.5.0/Phase 2b,
    # pending both the gleania and trust_growth host migrations). Gleania is
    # expected to migrate to host-side renderer classes under
    # `app/admin/renderers/*.rb` before then.
    #
    # The renderer bodies below are intentionally byte-equivalent to the
    # BaseHelper methods they replace, other than `resource` -> `record` and
    # routing BaseHelper method calls (`render_json_block`, `simple_format`,
    # `concat`) through `view.` — this class is not `included` into the view,
    # so those calls can't resolve as bare method sends the way they did
    # inside the helper module. Do not "improve" this markup: a byte-for-byte
    # move keeps gleania's Assistant/AI portal pages pixel-identical, and
    # makes the eventual 0.6.0 deletion a clean removal.
    module LegacyGleania
      extend AdminSuite::Deprecation

      DEPRECATION_MESSAGE_FORMAT =
        "AdminSuite: the :%<key>s renderer is deprecated and will be removed in 0.6.0. " \
        "Move it to app/admin/renderers in your app."

      class << self
        # Fires the deprecation sink at most once per `key` per process.
        # `warn_once_sink` and `reset_deprecation_notices!` come from
        # `AdminSuite::Deprecation`, extended above.
        #
        # @param key [Symbol]
        # @return [void]
        def warn_once(key)
          super(key, format(DEPRECATION_MESSAGE_FORMAT, key: key))
        end
      end

      # Verbatim from `BaseHelper#render_prompt_template`.
      class PromptTemplateRenderer < Renderer
        def render
          LegacyGleania.warn_once(:prompt_template_preview)

          template = record.respond_to?(:prompt_template) ? record.prompt_template : nil
          return content_tag(:p, "No template defined", class: "text-slate-500 italic") if template.blank?

          highlighted_template = h(template).gsub(/\{\{(\w+)\}\}/) do
            "<span class=\"text-amber-400 bg-amber-900/30 px-1 rounded\">{{#{$1}}}</span>"
          end

          content_tag(:div, class: "relative group") do
            view.concat(content_tag(:div, class: "absolute top-2 right-2 flex items-center gap-2") do
              view.concat(content_tag(:span, "TEMPLATE", class: "text-xs font-medium text-slate-400 uppercase tracking-wider"))
              view.concat(content_tag(:button,
                '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>'.html_safe,
                type: "button",
                class: "p-1 text-slate-400 hover:text-slate-600 opacity-0 group-hover:opacity-100 transition-opacity",
                data: { controller: "admin-suite--clipboard", action: "click->admin-suite--clipboard#copy", "admin-suite--clipboard-text-value": template },
                title: "Copy to clipboard"))
            end)

            view.concat(content_tag(:pre, class: "bg-slate-900 text-slate-100 p-4 rounded-lg overflow-x-auto text-sm font-mono max-h-[600px] overflow-y-auto whitespace-pre-wrap leading-relaxed") do
              highlighted_template.html_safe
            end)

            variables = template.scan(/\{\{(\w+)\}\}/).flatten.uniq
            if variables.any?
              view.concat(content_tag(:div, class: "mt-3 pt-3 border-t border-slate-700") do
                view.concat(content_tag(:span, "Variables: ", class: "text-sm text-slate-400"))
                view.concat(content_tag(:div, class: "inline-flex flex-wrap gap-1 mt-1") do
                  variables.each do |var|
                    view.concat(content_tag(:code, "{{#{var}}}", class: "text-xs px-2 py-0.5 bg-amber-900/30 text-amber-400 rounded"))
                  end
                end)
              end)
            end
          end
        end
      end

      # Verbatim from `BaseHelper#render_messages_preview`.
      class MessagesPreviewRenderer < Renderer
        def render
          LegacyGleania.warn_once(:messages_preview)

          messages = record.respond_to?(:messages) ? record.messages : []
          if messages.respond_to?(:chronological)
            messages = messages.chronological
          end
          messages = messages.limit(50) if messages.respond_to?(:limit)
          messages = Array.wrap(messages)

          return content_tag(:p, "No messages", class: "text-slate-500 italic") if messages.blank?

          content_tag(:div, class: "space-y-4 max-h-[600px] overflow-y-auto -mx-6 -mb-6 p-6 pt-0") do
            messages.each_with_index do |msg, idx|
              if msg.respond_to?(:role)
                role = msg.role
                content = msg.content
                created_at = msg.respond_to?(:created_at) ? msg.created_at : nil
              else
                role = msg["role"] || msg[:role] || "unknown"
                content = msg["content"] || msg[:content] || ""
                created_at = msg["created_at"] || msg[:created_at]
              end

              role_class = case role.to_s
              when "user" then "bg-blue-50 border-blue-200"
              when "assistant" then "bg-emerald-50 border-emerald-200"
              when "tool" then "bg-amber-50 border-amber-200"
              when "system" then "bg-slate-50 border-slate-200"
              else "bg-slate-50 border-slate-200"
              end

              role_icon = case role.to_s
              when "user"
                '<svg class="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>'.html_safe
              when "assistant"
                '<svg class="w-4 h-4 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"/></svg>'.html_safe
              when "tool"
                '<svg class="w-4 h-4 text-amber-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/></svg>'.html_safe
              else
                '<svg class="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/></svg>'.html_safe
              end

              view.concat(content_tag(:div, class: "rounded-lg border p-4 #{role_class}") do
                view.concat(content_tag(:div, class: "flex items-center justify-between mb-3") do
                  view.concat(content_tag(:div, class: "flex items-center gap-2") do
                    view.concat(role_icon)
                    view.concat(content_tag(:span, role.to_s.capitalize, class: "text-sm font-medium text-slate-700"))
                  end)
                  view.concat(content_tag(:div, class: "flex items-center gap-2 text-xs text-slate-400") do
                    view.concat(content_tag(:span, created_at.strftime("%H:%M:%S"))) if created_at.respond_to?(:strftime)
                    view.concat(content_tag(:span, "##{idx + 1}"))
                  end)
                end)

                content_str = content.to_s
                if role.to_s == "tool" && content_str.start_with?("{", "[")
                  begin
                    parsed = JSON.parse(content_str)
                    view.concat(view.render_json_block(parsed))
                  rescue JSON::ParserError
                    view.concat(content_tag(:div, view.simple_format(h(content_str)), class: "prose prose-sm max-w-none"))
                  end
                else
                  view.concat(content_tag(:div, view.simple_format(h(content_str)), class: "prose prose-sm max-w-none"))
                end
              end)
            end
          end
        end
      end

      # Verbatim from `BaseHelper#render_tool_args_preview`.
      class ToolArgsRenderer < Renderer
        def render
          LegacyGleania.warn_once(:tool_args_preview)

          args = record.respond_to?(:args) ? record.args : (record.respond_to?(:arguments) ? record.arguments : {})
          result = record.respond_to?(:result) ? record.result : nil
          error = record.respond_to?(:error) ? record.error : nil

          content_tag(:div, class: "space-y-6") do
            view.concat(content_tag(:div) do
              view.concat(content_tag(:h4, "Arguments", class: "text-sm font-medium text-slate-500 mb-2"))
              if args.present? && args != {}
                view.concat(view.render_json_block(args))
              else
                view.concat(content_tag(:p, "No arguments", class: "text-slate-400 italic text-sm"))
              end
            end)

            if result.present? && result != {}
              view.concat(content_tag(:div, class: "pt-4 border-t border-slate-200") do
                view.concat(content_tag(:h4, "Result", class: "text-sm font-medium text-slate-500 mb-2"))
                view.concat(view.render_json_block(result))
              end)
            end

            if error.present?
              view.concat(content_tag(:div, class: "pt-4 border-t border-slate-200") do
                view.concat(content_tag(:h4, "Error", class: "text-sm font-medium text-red-500 mb-2"))
                view.concat(content_tag(:div, class: "bg-red-50 border border-red-200 rounded-lg p-4") do
                  content_tag(:pre, h(error.to_s), class: "text-sm text-red-700 whitespace-pre-wrap font-mono")
                end)
              end)
            end
          end
        end
      end

      # Verbatim from `BaseHelper#render_turn_messages_preview`.
      class TurnMessagesRenderer < Renderer
        def render
          LegacyGleania.warn_once(:turn_messages_preview)

          user_msg = record.respond_to?(:user_message) ? record.user_message : nil
          asst_msg = record.respond_to?(:assistant_message) ? record.assistant_message : nil

          content_tag(:div, class: "space-y-4") do
            if user_msg
              view.concat(content_tag(:div, class: "rounded-lg border p-4 bg-blue-50 border-blue-200") do
                view.concat(content_tag(:div, class: "flex items-center gap-2 mb-2") do
                  view.concat('<svg class="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>'.html_safe)
                  view.concat(content_tag(:span, "User", class: "text-sm font-medium text-slate-700"))
                end)
                view.concat(content_tag(:div, view.simple_format(h(user_msg.respond_to?(:content) ? user_msg.content.to_s : user_msg.to_s)), class: "prose prose-sm max-w-none"))
              end)
            end

            if asst_msg
              view.concat(content_tag(:div, class: "rounded-lg border p-4 bg-emerald-50 border-emerald-200") do
                view.concat(content_tag(:div, class: "flex items-center gap-2 mb-2") do
                  view.concat('<svg class="w-4 h-4 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"/></svg>'.html_safe)
                  view.concat(content_tag(:span, "Assistant", class: "text-sm font-medium text-slate-700"))
                end)
                view.concat(content_tag(:div, view.simple_format(h(asst_msg.respond_to?(:content) ? asst_msg.content.to_s : asst_msg.to_s)), class: "prose prose-sm max-w-none"))
              end)
            end

            view.concat(content_tag(:p, "No messages found", class: "text-slate-400 italic text-sm")) unless user_msg || asst_msg
          end
        end
      end
    end
  end
end
