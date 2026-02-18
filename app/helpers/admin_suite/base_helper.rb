# frozen_string_literal: true

module AdminSuite
  # Helper methods for the Admin Suite engine UI.
  #
  # This is intentionally very close to the `/internal/developer` helper so we can
  # keep both UIs side-by-side and compare behavior while migrating.
  module BaseHelper
    include Pagy::Frontend
    include AdminSuite::IconHelper
    include AdminSuite::PanelsHelper
    include AdminSuite::ThemeHelper
    include ::Internal::Developer::CustomRenderersHelper if defined?(::Internal::Developer::CustomRenderersHelper)
    # ActiveStorage route helpers live on the host app (main_app), not the isolated engine.
    def admin_suite_rails_blob_path(...)
      if respond_to?(:main_app) && main_app.respond_to?(:rails_blob_path)
        main_app.rails_blob_path(...)
      else
        rails_blob_path(...)
      end
    end

    def admin_suite_rails_blob_representation_path(...)
      if respond_to?(:main_app) && main_app.respond_to?(:rails_blob_representation_path)
        main_app.rails_blob_representation_path(...)
      else
        rails_blob_representation_path(...)
      end
    end

    # Logout path/method/label in the topbar are host-configurable.
    def admin_suite_logout_path
      value = AdminSuite.config.respond_to?(:logout_path) ? AdminSuite.config.logout_path : nil
      resolve_admin_suite_view_config(value).presence
    end

    def admin_suite_logout_method
      value = AdminSuite.config.respond_to?(:logout_method) ? AdminSuite.config.logout_method : :delete
      resolved = resolve_admin_suite_view_config(value)
      resolved = resolved.to_sym if resolved.respond_to?(:to_sym)
      resolved.presence || :delete
    rescue StandardError
      :delete
    end

    def admin_suite_logout_label
      value = AdminSuite.config.respond_to?(:logout_label) ? AdminSuite.config.logout_label : nil
      resolved = resolve_admin_suite_view_config(value)
      resolved.to_s.presence || "Log out"
    end

    def resolve_admin_suite_view_config(value)
      return nil if value.nil?

      if value.respond_to?(:call)
        return value.call if value.arity.zero?
        return value.call(self)
      end

      if value.is_a?(Symbol)
        return nil unless respond_to?(value, true)
        return public_send(value)
      end

      value
    rescue StandardError
      nil
    end

    # Lookup the DSL field definition for a given attribute (if present).
    #
    # Used to render show values with type awareness (e.g. markdown/json/label).
    def admin_suite_field_definition(field_name)
      return nil unless respond_to?(:resource_config, true)

      rc = resource_config
      return nil unless rc

      rc.form_config&.fields_list.to_a.find do |f|
        f.respond_to?(:name) &&
          f.respond_to?(:type) &&
          f.name.to_sym == field_name.to_sym
      end
    rescue StandardError
      nil
    end


    # Prefer registry-driven implementations (with legacy fallbacks via `super`).
    prepend AdminSuite::UI::ShowValueFormatter
    prepend AdminSuite::UI::FormFieldRenderer

    # Returns the color scheme for a portal
    #
    # @param portal_key [Symbol] Portal identifier
    # @return [String]
    def portal_color(portal_key)
      portal_key = portal_key.to_sym
      color = (navigation_items.dig(portal_key, :color) rescue nil)
      return color.to_s if color.present?

      case portal_key
      when :ops then "amber"
      when :ai then "cyan"
      when :assistant then "violet"
      when :email then "emerald"
      else "slate"
      end
    end

    # Returns an icon for a portal.
    #
    # @param portal_key [Symbol] Portal identifier
    # @return [ActiveSupport::SafeBuffer, String]
    def portal_icon(portal_key, **opts)
      portal_key = portal_key.to_sym
      icon = (navigation_items.dig(portal_key, :icon) rescue nil)
      icon ||= begin
        {
          ops: "settings",
          ai: "sparkles",
          assistant: "bot",
          email: "mail"
        }[portal_key]
      end
      icon = icon.presence || "layout-grid"

      admin_suite_icon(icon, **opts)
    end

    # Renders a column value from a record
    #
    # @param record [ActiveRecord::Base] The record
    # @param column [Admin::Base::Resource::ColumnDefinition] Column definition
    # @return [String]
    def render_column_value(record, column)
      if column.type == :toggle
        field = (column.toggle_field || column.name).to_sym
        render partial: "admin_suite/shared/toggle_cell",
               locals: { record: record, field: field }
      elsif column.type == :label
        value = column.content.is_a?(Proc) ? column.content.call(record) : (record.public_send(column.name) rescue nil)
        render_label_badge(value, color: column.label_color, size: column.label_size, record: record)
      elsif column.content.is_a?(Proc)
        column.content.call(record)
      else
        record.public_send(column.name) rescue "—"
      end
    end

    # Formats a value for display on show pages
    #
    # @param record [ActiveRecord::Base] The record
    # @param field_name [Symbol, String] Field name
    # @return [String] HTML safe formatted value
    def format_show_value(record, field_name)
      value = record.public_send(field_name) rescue nil

      if value.is_a?(ActiveStorage::Attached::One)
        return render_attachment_preview(value)
      elsif value.is_a?(ActiveStorage::Attached::Many)
        return render_attachments_preview(value)
      end

      case value
      when nil
        content_tag(:span, "—", class: "text-slate-400")
      when true
        content_tag(:span, class: "inline-flex items-center gap-1") do
          svg = '<svg class="w-4 h-4 text-green-500" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>'.html_safe
          concat(svg)
          concat(content_tag(:span, "Yes", class: "text-green-600 font-medium"))
        end
      when false
        content_tag(:span, class: "inline-flex items-center gap-1") do
          svg = '<svg class="w-4 h-4 text-slate-400" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/></svg>'.html_safe
          concat(svg)
          concat(content_tag(:span, "No", class: "text-slate-500"))
        end
      when Time, DateTime
        content_tag(:span, class: "inline-flex items-center gap-2") do
          concat(content_tag(:span, value.strftime("%B %d, %Y at %H:%M"), class: "font-medium"))
          concat(content_tag(:span, "(#{time_ago_in_words(value)} ago)", class: "text-slate-500 text-xs"))
        end
      when Date
        value.strftime("%B %d, %Y")
      when ActiveRecord::Base
        link_text = value.respond_to?(:name) ? value.name : "#{value.class.name} ##{value.id}"
        content_tag(:span, link_text, class: "text-indigo-600")
      when Hash
        render_json_block(value)
      when Array
        if value.empty?
          content_tag(:span, "Empty array", class: "text-slate-400 italic")
        elsif value.first.is_a?(Hash)
          render_json_block(value)
        else
          content_tag(:div, class: "flex flex-wrap gap-1") do
            value.each do |item|
              concat(content_tag(:span, item.to_s, class: "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-slate-100 text-slate-700"))
            end
          end
        end
      when Integer, Float, BigDecimal
        content_tag(:span, number_with_delimiter(value), class: "font-mono")
      else
        value_str = value.to_s

        if value_str.start_with?("{", "[") && value_str.length > 10
          begin
            parsed = JSON.parse(value_str)
            render_json_block(parsed)
          rescue JSON::ParserError
            render_text_block(value_str)
          end
        elsif value_str.include?("\n") || value_str.length > 200
          render_text_block(value_str, detect_language(field_name, value_str))
        else
          value_str
        end
      end
    end

    def render_attachment_preview(attachment)
      return content_tag(:span, "—", class: "text-slate-400") unless attachment.attached?

      blob = attachment.blob

      if blob.image?
        variant = attachment.variant(resize_to_limit: [ 600, 400 ])
        variant_url =
          begin
            admin_suite_rails_blob_representation_path(variant.processed, only_path: true)
          rescue StandardError
            admin_suite_rails_blob_path(blob, disposition: :inline)
          end

        content_tag(:div, class: "space-y-2") do
          concat(content_tag(:div, class: "inline-block rounded-lg overflow-hidden border border-slate-200") do
            image_tag(variant_url,
              class: "max-w-full h-auto max-h-64 object-contain",
              alt: blob.filename.to_s)
          end)
          concat(content_tag(:div, class: "flex items-center gap-3 text-sm text-slate-500") do
            concat(content_tag(:span, blob.filename.to_s, class: "font-medium text-slate-700"))
            concat(content_tag(:span, "•"))
            concat(content_tag(:span, number_to_human_size(blob.byte_size)))
            concat(content_tag(:span, "•"))
            concat(link_to("View full size", admin_suite_rails_blob_path(blob, disposition: :inline), target: "_blank", class: "text-indigo-600 hover:underline"))
          end)
        end
      else
        content_tag(:div, class: "flex items-center gap-3 p-3 bg-slate-50 rounded-lg border border-slate-200") do
          concat(content_tag(:div, class: "flex-shrink-0 w-10 h-10 bg-slate-200 rounded-lg flex items-center justify-center") do
            '<svg class="w-5 h-5 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/></svg>'.html_safe
          end)
          concat(content_tag(:div, class: "flex-1 min-w-0") do
            concat(content_tag(:p, blob.filename.to_s, class: "font-medium text-slate-700 truncate"))
            concat(content_tag(:p, number_to_human_size(blob.byte_size), class: "text-sm text-slate-500"))
          end)
          concat(link_to("Download", admin_suite_rails_blob_path(blob, disposition: :attachment),
            class: "flex-shrink-0 px-3 py-1.5 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium rounded-lg transition-colors"))
        end
      end
    end

    def render_attachments_preview(attachments)
      return content_tag(:span, "—", class: "text-slate-400") unless attachments.attached?

      content_tag(:div, class: "grid grid-cols-2 md:grid-cols-3 gap-4") do
        attachments.each do |attachment|
          concat(render_attachment_preview(attachment))
        end
      end
    end

    def render_json_block(data)
      json_str = JSON.pretty_generate(data)

      content_tag(:div, class: "relative group") do
        concat(content_tag(:div, class: "absolute top-2 right-2 flex items-center gap-2") do
          concat(content_tag(:span, "JSON", class: "text-xs font-medium text-slate-400 uppercase tracking-wider"))
          concat(content_tag(:button,
            '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>'.html_safe,
            type: "button",
            class: "p-1 text-slate-400 hover:text-slate-600 opacity-0 group-hover:opacity-100 transition-opacity",
            data: { controller: "admin-suite--clipboard", action: "click->admin-suite--clipboard#copy", "admin-suite--clipboard-text-value": json_str },
            title: "Copy to clipboard"))
        end)

        concat(content_tag(:pre, class: "bg-slate-900 text-slate-100 p-4 rounded-lg overflow-x-auto text-sm font-mono max-h-96 overflow-y-auto") do
          content_tag(:code, class: "language-json") do
            highlight_json(json_str)
          end
        end)
      end
    end

    def render_text_block(text, language = nil)
      content_tag(:div, class: "relative group") do
        concat(content_tag(:div, class: "absolute top-2 right-2 flex items-center gap-2") do
          concat(content_tag(:span, language.to_s.upcase, class: "text-xs font-medium text-slate-400 uppercase tracking-wider")) if language
          concat(content_tag(:button,
            '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>'.html_safe,
            type: "button",
            class: "p-1 text-slate-400 hover:text-slate-600 opacity-0 group-hover:opacity-100 transition-opacity",
            data: { controller: "admin-suite--clipboard", action: "click->admin-suite--clipboard#copy", "admin-suite--clipboard-text-value": text },
            title: "Copy to clipboard"))
        end)

        concat(content_tag(:pre, class: "bg-slate-900 text-slate-100 p-4 rounded-lg overflow-x-auto text-sm font-mono max-h-96 overflow-y-auto whitespace-pre-wrap") do
          content_tag(:code, h(text), class: language ? "language-#{language}" : nil)
        end)
      end
    end

    def highlight_json(json_str)
      highlighted = h(json_str)
        .gsub(/("(?:[^"\\]|\\.)*")(\s*:)/) { "<span class=\"text-purple-400\">#{$1}</span>#{$2}" }
        .gsub(/:\s*("(?:[^"\\]|\\.)*")/) { ":<span class=\"text-green-400\">#{$1}</span>" }
        .gsub(/:\s*(true|false)/) { ":<span class=\"text-orange-400\">#{$1}</span>" }
        .gsub(/:\s*(-?\d+(?:\.\d+)?)/) { ":<span class=\"text-cyan-400\">#{$1}</span>" }
        .gsub(/:\s*(null)/) { ":<span class=\"text-red-400\">#{$1}</span>" }

      highlighted.html_safe
    end

    def detect_language(field_name, content)
      field_str = field_name.to_s.downcase

      return :markdown if field_str.include?("template") || field_str.include?("prompt")
      return :ruby if field_str.include?("code") && content.include?("def ")
      return :sql if field_str.include?("query") || field_str.include?("sql")
      return :html if field_str.include?("html") || field_str.include?("body")

      return :json if content.strip.start_with?("{", "[")
      return :ruby if content.include?("def ") || content.include?("class ")
      return :sql if content.upcase.include?("SELECT ") || content.upcase.include?("INSERT ")
      return :html if content.include?("<html") || content.include?("<div")

      nil
    end

    def render_custom_section(resource, render_type)
      renderer = AdminSuite.config.custom_renderers[render_type.to_sym] rescue nil
      return renderer.call(resource, self) if renderer

      case render_type.to_sym
      when :prompt_template_preview
        render_prompt_template(resource)
      when :json_preview
        render_json_preview(resource)
      when :code_preview
        render_code_preview(resource)
      when :messages_preview
        render_messages_preview(resource)
      when :tool_args_preview
        render_tool_args_preview(resource)
      when :turn_messages_preview
        render_turn_messages_preview(resource)
      else
        content_tag(:p, "Unknown render type: #{render_type}", class: "text-slate-500 italic")
      end
    end

    # --- generic custom renderers (fallbacks) ---
    def render_prompt_template(resource)
      template = resource.respond_to?(:prompt_template) ? resource.prompt_template : nil
      return content_tag(:p, "No template defined", class: "text-slate-500 italic") if template.blank?

      highlighted_template = h(template).gsub(/\{\{(\w+)\}\}/) do
        "<span class=\"text-amber-400 bg-amber-900/30 px-1 rounded\">{{#{$1}}}</span>"
      end

      content_tag(:div, class: "relative group") do
        concat(content_tag(:div, class: "absolute top-2 right-2 flex items-center gap-2") do
          concat(content_tag(:span, "TEMPLATE", class: "text-xs font-medium text-slate-400 uppercase tracking-wider"))
          concat(content_tag(:button,
            '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>'.html_safe,
            type: "button",
            class: "p-1 text-slate-400 hover:text-slate-600 opacity-0 group-hover:opacity-100 transition-opacity",
            data: { controller: "admin-suite--clipboard", action: "click->admin-suite--clipboard#copy", "admin-suite--clipboard-text-value": template },
            title: "Copy to clipboard"))
        end)

        concat(content_tag(:pre, class: "bg-slate-900 text-slate-100 p-4 rounded-lg overflow-x-auto text-sm font-mono max-h-[600px] overflow-y-auto whitespace-pre-wrap leading-relaxed") do
          highlighted_template.html_safe
        end)

        variables = template.scan(/\{\{(\w+)\}\}/).flatten.uniq
        if variables.any?
          concat(content_tag(:div, class: "mt-3 pt-3 border-t border-slate-700") do
            concat(content_tag(:span, "Variables: ", class: "text-sm text-slate-400"))
            concat(content_tag(:div, class: "inline-flex flex-wrap gap-1 mt-1") do
              variables.each do |var|
                concat(content_tag(:code, "{{#{var}}}", class: "text-xs px-2 py-0.5 bg-amber-900/30 text-amber-400 rounded"))
              end
            end)
          end)
        end
      end
    end

    def render_json_preview(resource)
      data = resource.respond_to?(:data) ? resource.data : resource.attributes
      render_json_block(data)
    end

    def render_code_preview(resource)
      code = resource.respond_to?(:code) ? resource.code : resource.to_s
      render_text_block(code, :ruby)
    end

    def render_messages_preview(resource)
      messages = resource.respond_to?(:messages) ? resource.messages : []
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

          concat(content_tag(:div, class: "rounded-lg border p-4 #{role_class}") do
            concat(content_tag(:div, class: "flex items-center justify-between mb-3") do
              concat(content_tag(:div, class: "flex items-center gap-2") do
                concat(role_icon)
                concat(content_tag(:span, role.to_s.capitalize, class: "text-sm font-medium text-slate-700"))
              end)
              concat(content_tag(:div, class: "flex items-center gap-2 text-xs text-slate-400") do
                concat(content_tag(:span, created_at.strftime("%H:%M:%S"))) if created_at.respond_to?(:strftime)
                concat(content_tag(:span, "##{idx + 1}"))
              end)
            end)

            content_str = content.to_s
            if role.to_s == "tool" && content_str.start_with?("{", "[")
              begin
                parsed = JSON.parse(content_str)
                concat(render_json_block(parsed))
              rescue JSON::ParserError
                concat(content_tag(:div, simple_format(h(content_str)), class: "prose prose-sm max-w-none"))
              end
            else
              concat(content_tag(:div, simple_format(h(content_str)), class: "prose prose-sm max-w-none"))
            end
          end)
        end
      end
    end

    def render_tool_args_preview(resource)
      args = resource.respond_to?(:args) ? resource.args : (resource.respond_to?(:arguments) ? resource.arguments : {})
      result = resource.respond_to?(:result) ? resource.result : nil
      error = resource.respond_to?(:error) ? resource.error : nil

      content_tag(:div, class: "space-y-6") do
        concat(content_tag(:div) do
          concat(content_tag(:h4, "Arguments", class: "text-sm font-medium text-slate-500 mb-2"))
          if args.present? && args != {}
            concat(render_json_block(args))
          else
            concat(content_tag(:p, "No arguments", class: "text-slate-400 italic text-sm"))
          end
        end)

        if result.present? && result != {}
          concat(content_tag(:div, class: "pt-4 border-t border-slate-200") do
            concat(content_tag(:h4, "Result", class: "text-sm font-medium text-slate-500 mb-2"))
            concat(render_json_block(result))
          end)
        end

        if error.present?
          concat(content_tag(:div, class: "pt-4 border-t border-slate-200") do
            concat(content_tag(:h4, "Error", class: "text-sm font-medium text-red-500 mb-2"))
            concat(content_tag(:div, class: "bg-red-50 border border-red-200 rounded-lg p-4") do
              content_tag(:pre, h(error.to_s), class: "text-sm text-red-700 whitespace-pre-wrap font-mono")
            end)
          end)
        end
      end
    end

    def render_turn_messages_preview(resource)
      user_msg = resource.respond_to?(:user_message) ? resource.user_message : nil
      asst_msg = resource.respond_to?(:assistant_message) ? resource.assistant_message : nil

      content_tag(:div, class: "space-y-4") do
        if user_msg
          concat(content_tag(:div, class: "rounded-lg border p-4 bg-blue-50 border-blue-200") do
            concat(content_tag(:div, class: "flex items-center gap-2 mb-2") do
              concat('<svg class="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>'.html_safe)
              concat(content_tag(:span, "User", class: "text-sm font-medium text-slate-700"))
            end)
            concat(content_tag(:div, simple_format(h(user_msg.respond_to?(:content) ? user_msg.content.to_s : user_msg.to_s)), class: "prose prose-sm max-w-none"))
          end)
        end

        if asst_msg
          concat(content_tag(:div, class: "rounded-lg border p-4 bg-emerald-50 border-emerald-200") do
            concat(content_tag(:div, class: "flex items-center gap-2 mb-2") do
              concat('<svg class="w-4 h-4 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"/></svg>'.html_safe)
              concat(content_tag(:span, "Assistant", class: "text-sm font-medium text-slate-700"))
            end)
            concat(content_tag(:div, simple_format(h(asst_msg.respond_to?(:content) ? asst_msg.content.to_s : asst_msg.to_s)), class: "prose prose-sm max-w-none"))
          end)
        end

        concat(content_tag(:p, "No messages found", class: "text-slate-400 italic text-sm")) unless user_msg || asst_msg
      end
    end

    def auto_admin_suite_path_for(item)
      return nil unless item.is_a?(ActiveRecord::Base)

      ensure_admin_resources_loaded_for!(item.class)

      resource = Admin::Base::Resource.registered_resources.find { |r| r.model_class == item.class }
      return nil unless resource&.portal_name && resource.respond_to?(:resource_name_plural)

      resource_path(portal: resource.portal_name, resource_name: resource.resource_name_plural, id: item.to_param)
    rescue StandardError
      nil
    end

    def ensure_admin_resources_loaded_for!(model_class)
      already_loaded = Admin::Base::Resource.registered_resources.any? { |r| r.model_class == model_class }
      return if already_loaded

      Array(AdminSuite.config.resource_globs).flat_map { |g| Dir[g] }.uniq.each do |file|
        require file
      end
    rescue NameError
      require "admin/base/resource"
      retry
    end

    # ---- show page sections / associations ----
    #
    # For parity, we keep the same section rendering and association displays used by
    # `/internal/developer`. This is intentionally "UI heavy".

    def render_show_section(resource, section, position = :main)
      is_association = section.association.present? && !resource.public_send(section.association).is_a?(ActiveRecord::Base) rescue false

      content_tag(:div, class: "bg-white rounded-xl border border-slate-200 overflow-hidden") do
        header_padding = position == :sidebar ? "px-4 py-2.5" : "px-6 py-3"
        header_text_size = position == :sidebar ? "text-sm" : ""
        header_border = is_association ? "" : "border-b border-slate-200"

        concat(content_tag(:div, class: "#{header_padding} #{header_border} bg-slate-50 flex items-center justify-between") do
          concat(content_tag(:h3, section.title, class: "font-medium text-slate-900 #{header_text_size}"))

          if section.association.present?
            assoc = resource.public_send(section.association) rescue nil
            if assoc && !assoc.is_a?(ActiveRecord::Base)
              count = assoc.count rescue 0
              color_class = count > 0 ? "bg-indigo-100 text-indigo-700" : "bg-slate-200 text-slate-600"
              concat(content_tag(:span, number_with_delimiter(count), class: "text-xs font-semibold px-2 py-0.5 rounded-full #{color_class}"))
            end
          end
        end)

        content_padding = position == :sidebar ? "p-4" : "p-6"
        if is_association && position == :main
          content_padding = section.paginate ? "pt-0 px-6 pb-0" : "pt-0 px-6 pb-6"
        end
        content_padding = "pt-0 p-4" if is_association && position == :sidebar

        concat(content_tag(:div, class: content_padding) do
          if section.render.present?
            render_custom_section(resource, section.render)
          elsif section.association.present?
            render_association_section(resource, section)
          elsif section.fields.any?
            position == :sidebar ? render_sidebar_fields(resource, section.fields) : render_main_fields(resource, section.fields)
          else
            content_tag(:p, "No content", class: "text-slate-400 italic text-sm")
          end
        end)
      end
    end

    def render_sidebar_fields(resource, fields)
      content_tag(:div, class: "space-y-3") do
        fields.each do |field_name|
          value = resource.public_send(field_name) rescue nil
          if value.is_a?(ActiveStorage::Attached::One) || value.is_a?(ActiveStorage::Attached::Many)
            concat(render_sidebar_attachment(value))
          else
            concat(content_tag(:div, class: "flex justify-between items-start gap-2") do
              concat(content_tag(:span, field_name.to_s.humanize, class: "text-xs font-medium text-slate-500 uppercase tracking-wider flex-shrink-0"))
              concat(content_tag(:span, class: "text-sm text-slate-900 text-right") { format_show_value(resource, field_name) })
            end)
          end
        end
      end
    end

    def render_sidebar_attachment(attachment)
      return content_tag(:div, class: "text-center py-4") { content_tag(:span, "No image", class: "text-slate-400 text-sm") } unless attachment.respond_to?(:attached?) && attachment.attached?

      single = attachment.is_a?(ActiveStorage::Attached::Many) ? attachment.first : attachment
      blob = single.blob
      if blob.image?
        variant = single.variant(resize_to_limit: [ 400, 300 ])
        variant_url =
          begin
            admin_suite_rails_blob_representation_path(variant.processed, only_path: true)
          rescue StandardError
            admin_suite_rails_blob_path(blob, disposition: :inline)
          end

        content_tag(:div, class: "space-y-2") do
          concat(content_tag(:div, class: "rounded-lg overflow-hidden border border-slate-200") do
            image_tag(variant_url, class: "w-full h-auto object-cover", alt: blob.filename.to_s)
          end)
          concat(content_tag(:div, class: "flex items-center justify-between text-xs text-slate-500") do
            concat(content_tag(:span, number_to_human_size(blob.byte_size)))
            concat(link_to("View full", admin_suite_rails_blob_path(blob, disposition: :inline), target: "_blank", class: "text-indigo-600 hover:underline"))
          end)
        end
      else
        content_tag(:div, class: "flex items-center gap-2 p-2 bg-slate-50 rounded-lg") do
          concat(content_tag(:div, class: "flex-shrink-0 w-8 h-8 bg-slate-200 rounded flex items-center justify-center") do
            '<svg class="w-4 h-4 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/></svg>'.html_safe
          end)
          concat(content_tag(:div, class: "flex-1 min-w-0") do
            concat(content_tag(:p, blob.filename.to_s.truncate(20), class: "text-xs font-medium text-slate-700 truncate"))
            concat(content_tag(:p, number_to_human_size(blob.byte_size), class: "text-xs text-slate-500"))
          end)
        end
      end
    end

    def render_main_fields(resource, fields)
      content_tag(:dl, class: "space-y-6") do
        fields.each do |field_name|
          concat(content_tag(:div) do
            concat(content_tag(:dt, field_name.to_s.humanize, class: "text-sm font-medium text-slate-500 mb-2"))
            concat(content_tag(:dd, class: "text-sm text-slate-900") { format_show_value(resource, field_name) })
          end)
        end
      end
    end

    # ---- association rendering ----
    def render_association_section(resource, section)
      associated = resource.public_send(section.association) rescue nil
      return content_tag(:p, "None found", class: "text-slate-400 italic text-sm") if associated.nil?

      is_single = !associated.respond_to?(:to_a) || associated.is_a?(ActiveRecord::Base)
      return render_association_card_single(associated, section) if is_single

      items = associated
      pagy = nil

      if section.paginate
        per_page = (section.per_page || section.limit || 20).to_i
        per_page = 1 if per_page < 1
        page_param = association_page_param(section)
        page = params[page_param].presence || 1
        total_count = associated.respond_to?(:count) ? associated.count : associated.to_a.size
        pagy = Pagy.new(count: total_count, page: page, limit: per_page, page_param: page_param)
        items = associated.respond_to?(:offset) ? associated.offset(pagy.offset).limit(per_page) : Array.wrap(associated)[pagy.offset, per_page] || []
      elsif section.limit
        items = associated.respond_to?(:limit) ? associated.limit(section.limit) : Array.wrap(associated).first(section.limit)
      end

      items = Array.wrap(items)
      return content_tag(:p, "None found", class: "text-slate-400 italic text-sm") if items.empty?

      content_tag(:div) do
        case section.display
        when :table
          concat(render_association_table(items, section))
        when :cards
          concat(render_association_cards(items, section))
        else
          concat(render_association_list(items, section))
        end
        concat(render_association_pagination(pagy)) if pagy
      end
    end

    def association_page_param(section) = "#{section.association}_page"

    def render_association_pagination(pagy)
      content_tag(:div, class: "-mx-6 border-t border-slate-200 bg-slate-50/50 px-6 py-3") do
        content_tag(:nav, class: "flex items-center justify-between", "aria-label" => "Pagination") do
          concat(pagy_prev_link(pagy))
          concat(pagy_page_links(pagy))
          concat(pagy_next_link(pagy))
        end
      end
    end

    def pagy_prev_link(pagy)
      if pagy.prev
        link_to("Prev", pagy_url_for(pagy, pagy.prev),
          class: "px-3 py-1.5 text-sm font-medium text-slate-700 bg-white border border-slate-300 rounded-lg hover:bg-slate-50 transition-colors")
      else
        content_tag(:span, "Prev",
          class: "px-3 py-1.5 text-sm font-medium text-slate-400 bg-slate-100 border border-slate-200 rounded-lg cursor-not-allowed")
      end
    end

    def pagy_next_link(pagy)
      if pagy.next
        link_to("Next", pagy_url_for(pagy, pagy.next),
          class: "px-3 py-1.5 text-sm font-medium text-slate-700 bg-white border border-slate-300 rounded-lg hover:bg-slate-50 transition-colors")
      else
        content_tag(:span, "Next",
          class: "px-3 py-1.5 text-sm font-medium text-slate-400 bg-slate-100 border border-slate-200 rounded-lg cursor-not-allowed")
      end
    end

    def pagy_page_links(pagy)
      content_tag(:div, class: "flex items-center gap-1") do
        pagy.series.each { |item| concat(render_pagy_series_item(pagy, item)) }
      end
    end

    def render_pagy_series_item(pagy, item)
      case item
      when Integer
        link_to(item, pagy_url_for(pagy, item),
          class: "px-2.5 py-1 text-sm font-medium text-slate-700 bg-white border border-slate-300 rounded hover:bg-slate-50 transition-colors")
      when String
        content_tag(:span, item, class: "px-2.5 py-1 text-sm font-semibold text-white bg-indigo-600 border border-indigo-600 rounded")
      when :gap
        content_tag(:span, "…", class: "px-2 text-sm text-slate-400")
      else
        ""
      end
    end

    def render_association_card_single(item, section)
      link_path = build_association_link(item, section)

      card_content = capture do
        concat(content_tag(:div, class: "flex items-center justify-between gap-3") do
          concat(content_tag(:div, class: "min-w-0 flex-1") do
            title = item_display_title(item)
            title_class = link_path ? "font-medium text-slate-900 group-hover:text-indigo-600" : "font-medium text-slate-900"
            concat(content_tag(:div, title, class: title_class))

            subtitle = []
            subtitle << item.status.to_s.humanize if item.respond_to?(:status) && item.status.present?
            subtitle << item.email_address if item.respond_to?(:email_address) && item.email_address.present?
            subtitle << item.tool_key if item.respond_to?(:tool_key) && item.tool_key.present?
            concat(content_tag(:div, subtitle.first, class: "text-sm text-slate-500 mt-0.5")) if subtitle.any?
          end)

          if link_path
            concat('<svg class="w-5 h-5 text-slate-300 group-hover:text-indigo-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>'.html_safe)
          end
        end)
      end

      link_path ? link_to(card_content, link_path, class: "flex items-center -m-4 p-4 rounded-lg hover:bg-indigo-50 transition-colors group") : content_tag(:div, card_content, class: "flex items-center")
    end

    def render_association_list(items, section)
      content_tag(:div, class: "divide-y divide-slate-200 -mx-6 -mt-2 -mb-6") do
        items.each do |item|
          link_path = build_association_link(item, section)
          wrapper = if link_path
            ->(content) { link_to(link_path, class: "block px-6 py-4 hover:bg-indigo-50/50 transition-colors group") { content } }
          else
            ->(content) { content_tag(:div, content, class: "px-6 py-4") }
          end

          concat(wrapper.call(capture do
            concat(content_tag(:div, class: "flex items-start justify-between gap-4") do
              concat(content_tag(:div, class: "min-w-0 flex-1") do
                concat(content_tag(:div, class: "flex items-center gap-2") do
                  title = item_display_title(item)
                  title_class = link_path ? "text-slate-900 group-hover:text-indigo-600" : "text-slate-900"
                  concat(content_tag(:span, title.truncate(60), class: "font-medium #{title_class} truncate"))
                  concat(render_status_badge(item.status, size: :sm)) if item.respond_to?(:status) && item.status.present?
                end)
              end)

              concat(content_tag(:div, class: "flex items-center gap-3 flex-shrink-0 text-xs text-slate-400") do
                concat(content_tag(:span, time_ago_in_words(item.created_at) + " ago")) if item.respond_to?(:created_at) && item.created_at
                if link_path
                  concat('<svg class="w-4 h-4 text-slate-300 group-hover:text-indigo-500 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>'.html_safe)
                end
              end)
            end)
          end))
        end
      end
    end

    # Minimal association table support (matches internal portal table UX enough for now).
    def render_association_table(items, section)
      columns = section.columns.presence || detect_table_columns(items.first)

      content_tag(:div, class: "overflow-x-auto -mx-6 -mt-1") do
        content_tag(:table, class: "min-w-full divide-y divide-slate-200") do
          concat(content_tag(:thead, class: "bg-slate-50/50") do
            content_tag(:tr) do
              Array.wrap(columns).each do |col|
                header = col.to_s.gsub(/_id$/, "").humanize
                concat(content_tag(:th, header, class: "px-4 py-2.5 text-left text-xs font-medium text-slate-500 uppercase tracking-wider first:pl-6"))
              end
              concat(content_tag(:th, "", class: "px-4 py-2.5 w-16"))
            end
          end)

          concat(content_tag(:tbody, class: "divide-y divide-slate-200") do
            items.each do |item|
              link_path = build_association_link(item, section)
              concat(content_tag(:tr, class: link_path ? "hover:bg-indigo-50/50 cursor-pointer group" : "") do
                Array.wrap(columns).each_with_index do |col, idx|
                  value = item.public_send(col) rescue nil
                  text = format_table_cell(value)
                  concat(content_tag(:td, text, class: (idx == 0 ? "px-4 py-3 text-sm first:pl-6" : "px-4 py-3 text-sm")))
                end
                concat(content_tag(:td, class: "px-4 py-3 text-right pr-6") do
                  link_path ? link_to("View", link_path, class: "inline-flex items-center text-indigo-600 hover:text-indigo-800 text-sm font-medium") : ""
                end)
              end)
            end
          end)
        end
      end
    end

    def render_association_cards(items, section)
      content_tag(:div, class: "grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1") do
        items.each do |item|
          link_path = build_association_link(item, section)
          card_class = "border border-slate-200 rounded-lg p-4 transition-all"
          card_class += link_path ? " hover:border-indigo-300 hover:shadow-md group cursor-pointer" : " hover:bg-slate-50"

          card_content = capture do
            concat(content_tag(:div, class: "flex items-start justify-between gap-2 mb-2") do
              title = item_display_title(item)
              title_class = link_path ? "font-medium text-slate-900 group-hover:text-indigo-600" : "font-medium text-slate-900"
              concat(content_tag(:span, title.truncate(35), class: title_class))
              concat(render_status_badge(item.status, size: :sm)) if item.respond_to?(:status) && item.status.present?
            end)
            concat(content_tag(:div, class: "flex items-center justify-between text-xs text-slate-400 pt-2 border-t border-slate-100") do
              concat(content_tag(:span, time_ago_in_words(item.created_at) + " ago")) if item.respond_to?(:created_at) && item.created_at
              concat('<svg class="w-4 h-4 text-slate-300 group-hover:text-indigo-500 group-hover:translate-x-0.5 transition-all" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>'.html_safe) if link_path
            end)
          end

          concat(link_path ? link_to(card_content, link_path, class: card_class) : content_tag(:div, card_content, class: card_class))
        end
      end
    end

    def detect_table_columns(item)
      return [ :id, :name, :created_at ] unless item
      priority = [ :name, :title, :status ]
      attrs = item.attributes.keys.map(&:to_sym)
      selected = priority.select { |c| attrs.include?(c) }
      selected << :created_at if selected.size < 5 && attrs.include?(:created_at)
      selected.take(5)
    end

    def format_table_cell(value)
      case value
      when nil then "—"
      when true, false then value ? "Yes" : "No"
      when Time, DateTime then value.strftime("%b %d, %H:%M")
      when Date then value.strftime("%b %d, %Y")
      when ActiveRecord::Base then item_display_title(value)
      else value.to_s.truncate(50)
      end
    end

    def item_display_title(item)
      return item.name if item.respond_to?(:name) && item.name.present?
      return item.title if item.respond_to?(:title) && item.title.present?
      return item.display_title if item.respond_to?(:display_title) && item.display_title.present?
      return item.content.to_s.truncate(50) if item.respond_to?(:content)

      "##{item.id}"
    end

    def build_association_link(item, section)
      if section.link_to.present?
        begin
          return send(section.link_to, item)
        rescue NoMethodError
          # fall through to auto-link
        end
      end

      auto_admin_suite_path_for(item)
    end

    def render_status_badge(status, size: :md)
      return content_tag(:span, "—", class: "text-slate-400") if status.blank?

      status_str = status.to_s.downcase
      colors = case status_str
      when "active", "open", "success", "approved", "completed", "enabled"
        "bg-green-100 text-green-700"
      when "pending", "proposed", "queued", "waiting"
        "bg-amber-100 text-amber-700"
      when "running", "processing", "in_progress"
        "bg-blue-100 text-blue-700"
      when "error", "failed", "rejected", "cancelled"
        "bg-red-100 text-red-700"
      else
        "bg-slate-100 text-slate-600"
      end

      padding = size == :sm ? "px-1.5 py-0.5 text-xs" : "px-2 py-1 text-xs"
      content_tag(:span, status_str.titleize, class: "inline-flex items-center #{padding} rounded-full font-medium #{colors}")
    end

    def render_label_badge(value, color: nil, size: :md, record: nil)
      return content_tag(:span, "—", class: "text-slate-400") if value.blank?

      label_color = resolve_label_option(color, record).presence || :slate
      label_size = resolve_label_option(size, record).presence || :md
      colors = label_badge_colors(label_color)
      padding = label_size.to_s == "sm" ? "px-1.5 py-0.5 text-xs" : "px-2 py-1 text-xs"
      content_tag(:span, value.to_s, class: "inline-flex items-center #{padding} rounded-md font-medium #{colors}")
    end

    def resolve_label_option(option, record)
      return option.call(record) if option.is_a?(Proc)
      option
    end

    def label_badge_colors(color)
      case color.to_s.downcase
      when "green"
        "bg-green-100 text-green-700"
      when "amber", "yellow", "orange"
        "bg-amber-100 text-amber-700"
      when "blue"
        "bg-blue-100 text-blue-700"
      when "red"
        "bg-red-100 text-red-700"
      when "indigo"
        "bg-indigo-100 text-indigo-700"
      when "purple"
        "bg-purple-100 text-purple-700"
      when "violet"
        "bg-violet-100 text-violet-700"
      when "emerald"
        "bg-emerald-100 text-emerald-700"
      when "cyan"
        "bg-cyan-100 text-cyan-700"
      else
        "bg-slate-100 text-slate-600"
      end
    end

    # ---- form fields ----
    def render_form_field(f, field, resource)
      return if field.if_condition.present? && !field.if_condition.call(resource)
      return if field.unless_condition.present? && field.unless_condition.call(resource)

      capture do
        concat(content_tag(:div, class: "form-group") do
          concat(f.label(field.name, class: "form-label") do
            concat(field.label)
            concat(content_tag(:span, " *", class: "text-red-500")) if field.required
          end)

          field_class = "form-input w-full"
          field_class += " border-red-500" if resource.errors[field.name].any?

          field_html = case field.type
          when :textarea then f.text_area(field.name, class: field_class, rows: field.rows || 4, placeholder: field.placeholder, readonly: field.readonly)
          when :url then f.url_field(field.name, class: field_class, placeholder: field.placeholder, readonly: field.readonly)
          when :email then f.email_field(field.name, class: field_class, placeholder: field.placeholder, readonly: field.readonly)
          when :number then f.number_field(field.name, class: field_class, placeholder: field.placeholder, readonly: field.readonly)
          when :toggle then render_toggle_field(f, field, resource)
          when :label
            label_value = resource.public_send(field.name) rescue nil
            render_label_badge(label_value, color: field.label_color, size: field.label_size, record: resource)
          when :select
            collection = field.collection.is_a?(Proc) ? field.collection.call : field.collection
            f.select(field.name, collection, { include_blank: true }, class: field_class, disabled: field.readonly)
          when :searchable_select then render_searchable_select(f, field, resource)
          when :multi_select, :tags then render_multi_select(f, field, resource)
          when :image, :attachment then render_file_upload(f, field, resource)
          when :trix, :rich_text then f.rich_text_area(field.name, class: "prose max-w-none")
          when :markdown
            f.text_area(field.name, class: "#{field_class} font-mono", rows: field.rows || 12, data: { controller: "admin-suite--markdown-editor" }, placeholder: field.placeholder)
          when :file then f.file_field(field.name, class: "form-input-file", accept: field.accept)
          when :datetime then f.datetime_local_field(field.name, class: field_class, readonly: field.readonly)
          when :date then f.date_field(field.name, class: field_class, readonly: field.readonly)
          when :time then f.time_field(field.name, class: field_class, readonly: field.readonly)
          when :json
            render("admin_suite/shared/json_editor_field", f: f, field: field, resource: resource)
          when :code then render_code_editor(f, field, resource)
          else
            f.text_field(field.name, class: field_class, placeholder: field.placeholder, readonly: field.readonly)
          end

          concat(field_html)

          concat(content_tag(:p, field.help, class: "mt-1 text-sm text-slate-500")) if field.help.present?
          concat(content_tag(:p, resource.errors[field.name].first, class: "mt-1 text-sm text-red-600")) if resource.errors[field.name].any?
        end)
      end
    end

    def render_toggle_field(_f, field, resource)
      checked = !!resource.public_send(field.name)
      param_key = resource.class.model_name.param_key

      content_tag(:div,
        class: "inline-flex items-center gap-3",
        data: {
          controller: "admin-suite--toggle-switch",
          "admin-suite--toggle-switch-active-class-value": "is-on",
          "admin-suite--toggle-switch-inactive-classes-value": ""
        }) do
        concat(content_tag(:button, type: "button",
          class: "admin-suite-toggle-track #{checked ? "is-on" : ""}",
          role: "switch",
          "aria-checked" => checked.to_s,
          data: { action: "click->admin-suite--toggle-switch#toggle", "admin-suite--toggle-switch-target": "button" },
          disabled: field.readonly) do
            content_tag(:span, "", class: "admin-suite-toggle-thumb", data: { "admin-suite--toggle-switch-target": "thumb" })
          end)

        concat(hidden_field_tag("#{param_key}[#{field.name}]", checked ? "1" : "0", id: "#{param_key}_#{field.name}", data: { "admin-suite--toggle-switch-target": "input" }))
        concat(content_tag(:span, checked ? "Enabled" : "Disabled", class: "text-sm font-medium text-slate-700", data: { "admin-suite--toggle-switch-target": "label" }))
      end
    end

    def render_searchable_select(_f, field, resource)
      param_key = resource.class.model_name.param_key
      current_value = resource.public_send(field.name)
      collection = field.collection.is_a?(Proc) ? field.collection.call : field.collection

      options_json = if collection.is_a?(Array)
        collection.map { |opt| opt.is_a?(Array) ? { value: opt[1], label: opt[0] } : { value: opt, label: opt.to_s.humanize } }.to_json
      else
        "[]"
      end

      current_label = if current_value.present? && collection.is_a?(Array)
        match = collection.find { |opt| opt.is_a?(Array) ? opt[1].to_s == current_value.to_s : opt.to_s == current_value.to_s }
        match.is_a?(Array) ? match[0] : match.to_s
      elsif current_value.present? && collection.is_a?(String)
        association_name = field.name.to_s.sub(/_id\z/, "")
        assoc = resource.public_send(association_name) if resource.respond_to?(association_name)
        if assoc.respond_to?(:name) && assoc.name.present?
          assoc.name
        elsif assoc.respond_to?(:title) && assoc.title.present?
          assoc.title
        else
          current_value
        end
      else
        current_value
      end

      content_tag(:div,
        data: {
          controller: "admin-suite--searchable-select",
          "admin-suite--searchable-select-options-value": options_json,
          "admin-suite--searchable-select-creatable-value": field.create_url.present?,
          "admin-suite--searchable-select-search-url-value": collection.is_a?(String) ? collection : "",
          "admin-suite--searchable-select-create-url-value": field.create_url.to_s
        },
        class: "relative") do
        concat(hidden_field_tag("#{param_key}[#{field.name}]", current_value, data: { "admin-suite--searchable-select-target": "input" }))
        concat(text_field_tag(nil, current_label,
          class: "form-input w-full",
          placeholder: field.placeholder || "Search...",
          autocomplete: "off",
          data: {
            "admin-suite--searchable-select-target": "search",
            action: "input->admin-suite--searchable-select#search focus->admin-suite--searchable-select#open keydown->admin-suite--searchable-select#keydown"
          }))
        concat(content_tag(:div, "",
          class: "absolute z-40 w-full mt-1 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg shadow-lg hidden max-h-60 overflow-y-auto",
          data: { "admin-suite--searchable-select-target": "dropdown" }))
      end
    end

    def render_multi_select(_f, field, resource)
      param_key = resource.class.model_name.param_key
      current_values =
        if resource.respond_to?("#{field.name}_list")
          resource.public_send("#{field.name}_list")
        elsif resource.respond_to?(field.name)
          Array.wrap(resource.public_send(field.name))
        else
          []
        end

      options =
        if field.collection.is_a?(Proc)
          field.collection.call
        elsif field.collection.is_a?(Array)
          field.collection
        else
          []
        end

      field_name = field.type == :tags ? "tag_list" : field.name
      full_field_name = "#{param_key}[#{field_name}][]"

      content_tag(:div,
        data: {
          controller: "admin-suite--tag-select",
          "admin-suite--tag-select-creatable-value": field.create_url.present? || field.type == :tags,
          "admin-suite--tag-select-field-name-value": full_field_name
        },
        class: "space-y-2") do
        concat(hidden_field_tag(full_field_name, "", id: nil, data: { "admin-suite--tag-select-target": "placeholder" }))

        concat(content_tag(:div,
          class: "flex flex-wrap gap-2 min-h-[2.5rem] p-2 bg-white border border-slate-200 rounded-lg",
          data: { "admin-suite--tag-select-target": "tags" }) do
            current_values.each do |val|
              concat(content_tag(:span,
                class: "inline-flex items-center gap-1 px-2 py-1 bg-indigo-100 text-indigo-700 rounded text-sm") do
                  concat(val.to_s)
                  concat(hidden_field_tag(full_field_name, val, id: nil))
                  concat(button_tag("×", type: "button", class: "text-indigo-500 hover:text-indigo-700 font-bold", data: { action: "admin-suite--tag-select#remove" }))
                end)
            end
            concat(text_field_tag(nil, "",
              class: "flex-1 min-w-[120px] border-none focus:outline-none focus:ring-0 bg-transparent text-sm",
              placeholder: field.placeholder || "Add tag...",
              autocomplete: "off",
              data: { "admin-suite--tag-select-target": "input", action: "keydown->admin-suite--tag-select#keydown input->admin-suite--tag-select#search" }))
          end)

        if options.any?
          concat(content_tag(:div,
            class: "hidden border border-slate-200 rounded-lg bg-white shadow-lg max-h-48 overflow-y-auto",
            data: { "admin-suite--tag-select-target": "dropdown" }) do
              options.each do |opt|
                label, value = opt.is_a?(Array) ? [ opt[0], opt[1] ] : [ opt, opt ]
                concat(content_tag(:button, label,
                  type: "button",
                  class: "block w-full text-left px-3 py-2 text-sm hover:bg-slate-100",
                  data: { action: "admin-suite--tag-select#select", value: value }))
              end
            end)
        end
      end
    end

    def render_file_upload(f, field, resource)
      attachment = resource.respond_to?(field.name) ? resource.public_send(field.name) : nil
      has_attachment = attachment.respond_to?(:attached?) && attachment.attached?
      is_image = field.type == :image || (field.accept.present? && field.accept.include?("image"))
      existing_url =
        if has_attachment && is_image
          variant = attachment.variant(resize_to_limit: [ 300, 300 ])
          begin
            admin_suite_rails_blob_representation_path(variant.processed, only_path: true)
          rescue StandardError
            admin_suite_rails_blob_path(attachment.blob, disposition: :inline)
          end
        end

      content_tag(:div,
        data: {
          controller: "admin-suite--file-upload",
          "admin-suite--file-upload-accept-value": field.accept || (is_image ? "image/*" : "*/*"),
          "admin-suite--file-upload-preview-value": field.type == :image,
          "admin-suite--file-upload-existing-url-value": existing_url
        },
        class: "space-y-3") do
        if has_attachment && is_image
          concat(content_tag(:div, class: "relative inline-block") do
            concat(image_tag(existing_url, class: "max-w-[200px] max-h-[150px] rounded-lg border border-slate-200 object-cover", data: { "admin-suite--file-upload-target": "imagePreview" }))
            concat(button_tag("×", type: "button",
              class: "absolute -top-2 -right-2 w-6 h-6 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center text-sm",
              data: { "admin-suite--file-upload-target": "removeButton", action: "admin-suite--file-upload#remove" }))
          end)
        else
          concat(image_tag("", class: "hidden max-w-[200px] max-h-[150px] rounded-lg border border-slate-200 object-cover", data: { "admin-suite--file-upload-target": "imagePreview" }))
          concat(content_tag(:div, "", class: "hidden", data: { "admin-suite--file-upload-target": "filename" }))
        end

        concat(content_tag(:div,
          class: "relative border-2 border-dashed border-slate-300 rounded-lg hover:border-indigo-400 transition-colors",
          data: { "admin-suite--file-upload-target": "dropzone" }) do
            concat(f.file_field(field.name,
              class: "sr-only",
              id: "#{field.name}_input",
              accept: field.accept || (is_image ? "image/*" : nil),
              data: { "admin-suite--file-upload-target": "input", action: "change->admin-suite--file-upload#preview" }))

            concat(content_tag(:label, for: "#{field.name}_input",
              class: "flex flex-col items-center justify-center w-full py-6 cursor-pointer hover:bg-slate-50 rounded-lg transition-colors") do
                concat('<svg class="w-8 h-8 text-slate-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/></svg>'.html_safe)
                concat(content_tag(:span, "Click to upload or drag and drop", class: "text-sm text-slate-500"))
                concat(content_tag(:span, "PNG, JPG, WebP up to 10MB", class: "text-xs text-slate-400 mt-1")) if is_image
              end)
          end)
      end
    end

    def render_code_editor(f, field, _resource)
      content_tag(:div, class: "relative", data: { controller: "admin-suite--code-editor" }) do
        f.text_area(field.name,
          class: "w-full font-mono text-sm bg-slate-900 text-slate-100 p-4 rounded-lg border border-slate-700 focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500",
          rows: field.rows || 12,
          placeholder: field.placeholder,
          data: { "admin-suite--code-editor-target": "textarea" })
      end
    end
  end
end
