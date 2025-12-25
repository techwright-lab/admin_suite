# frozen_string_literal: true

module Internal
  module Developer
    # Helper methods for the developer portal
    module BaseHelper
      # Returns the color scheme for a portal
      #
      # @param portal_key [Symbol] Portal identifier
      # @return [String]
      def portal_color(portal_key)
        case portal_key
        when :ops then "amber"
        when :ai then "cyan"
        when :assistant then "violet"
        else "slate"
        end
      end

      # Returns the icon SVG for a portal
      #
      # @param portal_key [Symbol] Portal identifier
      # @return [String] HTML safe SVG icon
      def portal_icon(portal_key)
        case portal_key
        when :ops
          '<svg class="w-3 h-3 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>'.html_safe
        when :ai
          '<svg class="w-3 h-3 text-cyan-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"/></svg>'.html_safe
        when :assistant
          '<svg class="w-3 h-3 text-violet-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/></svg>'.html_safe
        else
          '<svg class="w-3 h-3 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"/></svg>'.html_safe
        end
      end

      # Renders a column value from a record
      #
      # @param record [ActiveRecord::Base] The record
      # @param column [ColumnDefinition] Column definition
      # @return [String]
      def render_column_value(record, column)
        # Handle toggle columns specially
        if column.type == :toggle
          field = column.toggle_field || column.name
          render partial: "internal/developer/shared/toggle_cell", 
                 locals: { record: record, field: field }
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

        case value
        when nil
          content_tag(:span, "—", class: "text-slate-400")
        when true
          content_tag(:span, class: "inline-flex items-center gap-1") do
            svg = '<svg class="w-4 h-4 text-green-500" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>'.html_safe
            concat(svg)
            concat(content_tag(:span, "Yes", class: "text-green-600 dark:text-green-400 font-medium"))
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
            concat(content_tag(:span, "(#{time_ago_in_words(value)} ago)", class: "text-slate-500 dark:text-slate-400 text-xs"))
          end
        when Date
          value.strftime("%B %d, %Y")
        when ActiveRecord::Base
          link_text = value.respond_to?(:name) ? value.name : "#{value.class.name} ##{value.id}"
          content_tag(:span, link_text, class: "text-indigo-600 dark:text-indigo-400")
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
                concat(content_tag(:span, item.to_s, class: "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-300"))
              end
            end
          end
        when Integer, Float, BigDecimal
          content_tag(:span, number_with_delimiter(value), class: "font-mono")
        else
          value_str = value.to_s
          
          # Check if it looks like JSON
          if value_str.start_with?("{", "[") && value_str.length > 10
            begin
              parsed = JSON.parse(value_str)
              render_json_block(parsed)
            rescue JSON::ParserError
              render_text_block(value_str)
            end
          # Check if it's multi-line or long text (likely code/template)
          elsif value_str.include?("\n") || value_str.length > 200
            render_text_block(value_str, detect_language(field_name, value_str))
          else
            # Regular text
            value_str
          end
        end
      end

      # Renders a JSON block with syntax highlighting
      #
      # @param data [Hash, Array] The data to render
      # @return [String] HTML safe JSON block
      def render_json_block(data)
        json_str = JSON.pretty_generate(data)
        
        content_tag(:div, class: "relative group") do
          concat(content_tag(:div, class: "absolute top-2 right-2 flex items-center gap-2") do
            concat(content_tag(:span, "JSON", class: "text-xs font-medium text-slate-400 dark:text-slate-500 uppercase tracking-wider"))
            concat(content_tag(:button, 
              '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>'.html_safe,
              type: "button",
              class: "p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 opacity-0 group-hover:opacity-100 transition-opacity",
              data: { controller: "clipboard", action: "click->clipboard#copy", clipboard_text_value: json_str },
              title: "Copy to clipboard"))
          end)
          
          concat(content_tag(:pre, class: "bg-slate-900 text-slate-100 p-4 rounded-lg overflow-x-auto text-sm font-mono max-h-96 overflow-y-auto") do
            content_tag(:code, class: "language-json") do
              highlight_json(json_str)
            end
          end)
        end
      end

      # Renders a text/code block
      #
      # @param text [String] The text to render
      # @param language [Symbol, nil] Optional language for syntax highlighting
      # @return [String] HTML safe text block
      def render_text_block(text, language = nil)
        content_tag(:div, class: "relative group") do
          concat(content_tag(:div, class: "absolute top-2 right-2 flex items-center gap-2") do
            if language
              concat(content_tag(:span, language.to_s.upcase, class: "text-xs font-medium text-slate-400 dark:text-slate-500 uppercase tracking-wider"))
            end
            concat(content_tag(:button, 
              '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>'.html_safe,
              type: "button",
              class: "p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 opacity-0 group-hover:opacity-100 transition-opacity",
              data: { controller: "clipboard", action: "click->clipboard#copy", clipboard_text_value: text },
              title: "Copy to clipboard"))
          end)
          
          concat(content_tag(:pre, class: "bg-slate-900 text-slate-100 p-4 rounded-lg overflow-x-auto text-sm font-mono max-h-96 overflow-y-auto whitespace-pre-wrap") do
            content_tag(:code, h(text), class: language ? "language-#{language}" : nil)
          end)
        end
      end

      # Highlights JSON string with colors
      #
      # @param json_str [String] The JSON string
      # @return [String] HTML safe highlighted JSON
      def highlight_json(json_str)
        # Simple JSON syntax highlighting
        highlighted = h(json_str)
          .gsub(/("(?:[^"\\]|\\.)*")(\s*:)/) do |match|
            key = $1
            colon = $2
            "<span class=\"text-purple-400\">#{key}</span>#{colon}"
          end
          .gsub(/:\s*("(?:[^"\\]|\\.)*")/) do |match|
            ":<span class=\"text-green-400\">#{$1}</span>"
          end
          .gsub(/:\s*(true|false)/) do |match|
            ":<span class=\"text-orange-400\">#{$1}</span>"
          end
          .gsub(/:\s*(-?\d+(?:\.\d+)?)/) do |match|
            ":<span class=\"text-cyan-400\">#{$1}</span>"
          end
          .gsub(/:\s*(null)/) do |match|
            ":<span class=\"text-red-400\">#{$1}</span>"
          end
        
        highlighted.html_safe
      end

      # Detects the language type from field name and content
      #
      # @param field_name [Symbol, String] Field name
      # @param content [String] Content to analyze
      # @return [Symbol, nil] Detected language
      def detect_language(field_name, content)
        field_str = field_name.to_s.downcase
        
        # Check field name hints
        return :markdown if field_str.include?("template") || field_str.include?("prompt")
        return :ruby if field_str.include?("code") && content.include?("def ")
        return :sql if field_str.include?("query") || field_str.include?("sql")
        return :html if field_str.include?("html") || field_str.include?("body")
        
        # Check content hints
        return :json if content.strip.start_with?("{", "[")
        return :ruby if content.include?("def ") || content.include?("class ")
        return :sql if content.upcase.include?("SELECT ") || content.upcase.include?("INSERT ")
        return :html if content.include?("<html") || content.include?("<div")
        
        # Default to text for multi-line content
        nil
      end

      # Renders a custom section based on the render type
      #
      # @param resource [ActiveRecord::Base] The record
      # @param render_type [Symbol] Type of custom render
      # @return [String] HTML safe rendered content
      def render_custom_section(resource, render_type)
        case render_type
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
        else
          content_tag(:p, "Unknown render type: #{render_type}", class: "text-slate-500 italic")
        end
      end

      # Renders a prompt template with variable highlighting
      #
      # @param resource [ActiveRecord::Base] The record
      # @return [String] HTML safe template preview
      def render_prompt_template(resource)
        template = resource.respond_to?(:prompt_template) ? resource.prompt_template : nil
        
        return content_tag(:p, "No template defined", class: "text-slate-500 italic") if template.blank?

        # Highlight template variables
        highlighted_template = h(template).gsub(/\{\{(\w+)\}\}/) do |match|
          "<span class=\"text-amber-400 bg-amber-900/30 px-1 rounded\">{{#{$1}}}</span>"
        end

        content_tag(:div, class: "relative group") do
          concat(content_tag(:div, class: "absolute top-2 right-2 flex items-center gap-2") do
            concat(content_tag(:span, "TEMPLATE", class: "text-xs font-medium text-slate-400 dark:text-slate-500 uppercase tracking-wider"))
            concat(content_tag(:button, 
              '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>'.html_safe,
              type: "button",
              class: "p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 opacity-0 group-hover:opacity-100 transition-opacity",
              data: { controller: "clipboard", action: "click->clipboard#copy", clipboard_text_value: template },
              title: "Copy to clipboard"))
          end)
          
          concat(content_tag(:pre, class: "bg-slate-900 text-slate-100 p-4 rounded-lg overflow-x-auto text-sm font-mono max-h-[600px] overflow-y-auto whitespace-pre-wrap leading-relaxed") do
            highlighted_template.html_safe
          end)
          
          # Show template variables
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

      # Renders a JSON preview (for arbitrary JSON fields)
      #
      # @param resource [ActiveRecord::Base] The record
      # @return [String] HTML safe JSON preview
      def render_json_preview(resource)
        data = resource.respond_to?(:data) ? resource.data : resource.attributes
        render_json_block(data)
      end

      # Renders a code preview
      #
      # @param resource [ActiveRecord::Base] The record
      # @return [String] HTML safe code preview
      def render_code_preview(resource)
        code = resource.respond_to?(:code) ? resource.code : resource.to_s
        render_text_block(code, :ruby)
      end

      # Renders messages preview (for chat threads)
      #
      # @param resource [ActiveRecord::Base] The record
      # @return [String] HTML safe messages preview
      def render_messages_preview(resource)
        messages = resource.respond_to?(:messages) ? resource.messages.chronological.limit(50) : []
        
        return content_tag(:p, "No messages", class: "text-slate-500 italic") if messages.blank?

        content_tag(:div, class: "space-y-4 max-h-[600px] overflow-y-auto -mx-6 -mb-6 p-6 pt-0") do
          messages.each_with_index do |msg, idx|
            # Handle both ActiveRecord objects and Hash messages
            if msg.respond_to?(:role)
              role = msg.role
              content = msg.content
              created_at = msg.created_at
            else
              role = msg["role"] || msg[:role] || "unknown"
              content = msg["content"] || msg[:content] || ""
              created_at = nil
            end
            
            role_class = case role.to_s
            when "user" then "bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800"
            when "assistant" then "bg-emerald-50 dark:bg-emerald-900/20 border-emerald-200 dark:border-emerald-800"
            when "tool" then "bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-800"
            when "system" then "bg-slate-50 dark:bg-slate-700/50 border-slate-200 dark:border-slate-600"
            else "bg-slate-50 dark:bg-slate-800 border-slate-200 dark:border-slate-700"
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
                  concat(content_tag(:span, role.to_s.capitalize, class: "text-sm font-medium text-slate-700 dark:text-slate-200"))
                end)
                concat(content_tag(:div, class: "flex items-center gap-2 text-xs text-slate-400") do
                  if created_at
                    concat(content_tag(:span, created_at.strftime("%H:%M:%S")))
                  end
                  concat(content_tag(:span, "##{idx + 1}"))
                end)
              end)
              
              # Render content - detect if it's JSON or code
              content_str = content.to_s
              if role.to_s == "tool" && content_str.start_with?("{", "[")
                begin
                  parsed = JSON.parse(content_str)
                  concat(render_json_block(parsed))
                rescue JSON::ParserError
                  concat(content_tag(:div, simple_format(h(content_str)), class: "prose dark:prose-invert prose-sm max-w-none"))
                end
              else
                concat(content_tag(:div, simple_format(h(content_str)), class: "prose dark:prose-invert prose-sm max-w-none"))
              end
            end)
          end
        end
      end

      # Renders tool arguments preview
      #
      # @param resource [ActiveRecord::Base] The record
      # @return [String] HTML safe tool args preview
      def render_tool_args_preview(resource)
        # ToolExecution uses 'args' not 'arguments'
        args = resource.respond_to?(:args) ? resource.args : (resource.respond_to?(:arguments) ? resource.arguments : {})
        result = resource.respond_to?(:result) ? resource.result : nil
        error = resource.respond_to?(:error) ? resource.error : nil
        
        content_tag(:div, class: "space-y-6") do
          # Arguments section
          concat(content_tag(:div) do
            concat(content_tag(:h4, "Arguments", class: "text-sm font-medium text-slate-500 dark:text-slate-400 mb-2"))
            if args.present? && args != {}
              concat(render_json_block(args))
            else
              concat(content_tag(:p, "No arguments", class: "text-slate-400 italic text-sm"))
            end
          end)
          
          # Result section
          if result.present? && result != {}
            concat(content_tag(:div, class: "pt-4 border-t border-slate-200 dark:border-slate-700") do
              concat(content_tag(:h4, "Result", class: "text-sm font-medium text-slate-500 dark:text-slate-400 mb-2"))
              concat(render_json_block(result))
            end)
          end
          
          # Error section
          if error.present?
            concat(content_tag(:div, class: "pt-4 border-t border-slate-200 dark:border-slate-700") do
              concat(content_tag(:h4, "Error", class: "text-sm font-medium text-red-500 dark:text-red-400 mb-2"))
              concat(content_tag(:div, class: "bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-4") do
                content_tag(:pre, h(error.to_s), class: "text-sm text-red-700 dark:text-red-300 whitespace-pre-wrap font-mono")
              end)
            end)
          end
        end
      end

      # Renders a show page section based on its configuration
      #
      # @param resource [ActiveRecord::Base] The record
      # @param section [ShowSectionDefinition] Section definition
      # @param position [Symbol] :sidebar or :main
      # @return [String] HTML safe section
      def render_show_section(resource, section, position = :main)
        # Check if this is an association section (needs tighter header-content spacing)
        is_association = section.association.present? && !resource.public_send(section.association).is_a?(ActiveRecord::Base) rescue false
        
        content_tag(:div, class: "bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden") do
          # Header
          header_padding = position == :sidebar ? "px-4 py-2.5" : "px-6 py-3"
          header_text_size = position == :sidebar ? "text-sm" : ""
          header_border = is_association ? "" : "border-b border-slate-200 dark:border-slate-700"
          
          concat(content_tag(:div, class: "#{header_padding} #{header_border} bg-slate-50 dark:bg-slate-900/50 flex items-center justify-between") do
            concat(content_tag(:h3, section.title, class: "font-medium text-slate-900 dark:text-white #{header_text_size}"))
            
            # Show count for associations
            if section.association.present?
              assoc = resource.public_send(section.association) rescue nil
              if assoc && !assoc.is_a?(ActiveRecord::Base)
                count = assoc.count rescue 0
                color_class = count > 0 ? "bg-indigo-100 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-400" : "bg-slate-200 dark:bg-slate-600 text-slate-600 dark:text-slate-300"
                concat(content_tag(:span, number_with_delimiter(count), class: "text-xs font-semibold px-2 py-0.5 rounded-full #{color_class}"))
              end
            end
          end)
          
          # Content
          content_padding = position == :sidebar ? "p-4" : "p-6"
          content_padding = "pt-0 px-6 pb-6" if is_association && position == :main
          content_padding = "pt-0 p-4" if is_association && position == :sidebar
          
          concat(content_tag(:div, class: content_padding) do
            if section.render.present?
              # Custom renderer
              render_custom_section(resource, section.render)
            elsif section.association.present?
              # Association display
              render_association_section(resource, section)
            elsif section.fields.any?
              # Field display
              if position == :sidebar
                render_sidebar_fields(resource, section.fields)
              else
                render_main_fields(resource, section.fields)
              end
            else
              content_tag(:p, "No content", class: "text-slate-400 italic text-sm")
            end
          end)
        end
      end

      # Renders fields for sidebar (compact layout)
      #
      # @param resource [ActiveRecord::Base] The record
      # @param fields [Array<Symbol>] Field names
      # @return [String] HTML safe fields
      def render_sidebar_fields(resource, fields)
        content_tag(:div, class: "space-y-3") do
          fields.each do |field_name|
            concat(content_tag(:div, class: "flex justify-between items-start gap-2") do
              concat(content_tag(:span, field_name.to_s.humanize, class: "text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider flex-shrink-0"))
              concat(content_tag(:span, class: "text-sm text-slate-900 dark:text-white text-right") do
                format_show_value(resource, field_name)
              end)
            end)
          end
        end
      end

      # Renders fields for main content (full layout)
      #
      # @param resource [ActiveRecord::Base] The record
      # @param fields [Array<Symbol>] Field names
      # @return [String] HTML safe fields
      def render_main_fields(resource, fields)
        content_tag(:dl, class: "space-y-6") do
          fields.each do |field_name|
            concat(content_tag(:div) do
              concat(content_tag(:dt, field_name.to_s.humanize, class: "text-sm font-medium text-slate-500 dark:text-slate-400 mb-2"))
              concat(content_tag(:dd, class: "text-sm text-slate-900 dark:text-white") do
                format_show_value(resource, field_name)
              end)
            end)
          end
        end
      end

      # Renders an association section
      #
      # @param resource [ActiveRecord::Base] The record
      # @param section [ShowSectionDefinition] Section definition
      # @return [String] HTML safe association display
      def render_association_section(resource, section)
        associated = resource.public_send(section.association) rescue nil
        
        return content_tag(:p, "None found", class: "text-slate-400 italic text-sm") if associated.nil?
        
        # Check if this is a belongs_to (single record) or has_many (collection)
        is_single = !associated.respond_to?(:to_a) || associated.is_a?(ActiveRecord::Base)
        
        if is_single
          # Single record (belongs_to)
          return render_association_card_single(associated, section)
        end
        
        # Apply limit if specified
        associated = associated.limit(section.limit) if section.limit && associated.respond_to?(:limit)
        
        # Convert to array for rendering
        items = associated.to_a
        
        return content_tag(:p, "None found", class: "text-slate-400 italic text-sm") if items.empty?

        case section.display
        when :table
          render_association_table(items, section)
        when :cards
          render_association_cards(items, section)
        else
          render_association_list(items, section)
        end
      end
      
      # Renders a single associated record (belongs_to)
      #
      # @param item [ActiveRecord::Base] The associated record
      # @param section [ShowSectionDefinition] Section definition
      # @return [String] HTML safe card
      def render_association_card_single(item, section)
        link_path = section.link_to.present? ? build_association_link(item, section) : nil
        
        card_content = capture do
          # Title row
          concat(content_tag(:div, class: "flex items-center justify-between gap-3") do
            concat(content_tag(:div, class: "min-w-0 flex-1") do
              title = item_display_title(item)
              title_class = link_path ? "font-medium text-slate-900 dark:text-white group-hover:text-indigo-600 dark:group-hover:text-indigo-400" : "font-medium text-slate-900 dark:text-white"
              concat(content_tag(:div, title, class: title_class))
              
              # Subtitle with extra info
              subtitle = []
              subtitle << item.status.to_s.humanize if item.respond_to?(:status) && item.status.present?
              subtitle << item.email_address if item.respond_to?(:email_address) && item.email_address.present?
              subtitle << item.tool_key if item.respond_to?(:tool_key) && item.tool_key.present?
              
              if subtitle.any?
                concat(content_tag(:div, subtitle.first, class: "text-sm text-slate-500 dark:text-slate-400 mt-0.5"))
              end
            end)
            
            if link_path
              concat('<svg class="w-5 h-5 text-slate-300 dark:text-slate-600 group-hover:text-indigo-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>'.html_safe)
            end
          end)
        end
        
        if link_path
          link_to(card_content, link_path, class: "flex items-center -m-4 p-4 rounded-lg hover:bg-indigo-50 dark:hover:bg-indigo-900/10 transition-colors group")
        else
          content_tag(:div, card_content, class: "flex items-center")
        end
      end

      # Renders association as a list
      #
      # @param items [Array] Associated records
      # @param section [ShowSectionDefinition] Section definition
      # @return [String] HTML safe list
      def render_association_list(items, section)
        content_tag(:div, class: "divide-y divide-slate-200 dark:divide-slate-700 -mx-6 -mt-2 -mb-6") do
          items.each do |item|
            link_path = section.link_to.present? ? build_association_link(item, section) : nil
            
            wrapper = if link_path
              -> (content) { link_to(link_path, class: "block px-6 py-4 hover:bg-indigo-50/50 dark:hover:bg-indigo-900/10 transition-colors group") { content } }
            else
              -> (content) { content_tag(:div, content, class: "px-6 py-4") }
            end
            
            concat(wrapper.call(capture do
              # Main row
              concat(content_tag(:div, class: "flex items-start justify-between gap-4") do
                # Left: Title and subtitle
                concat(content_tag(:div, class: "min-w-0 flex-1") do
                  # Title with link indicator
                  concat(content_tag(:div, class: "flex items-center gap-2") do
                    title = item_display_title(item)
                    title_class = link_path ? "text-slate-900 dark:text-white group-hover:text-indigo-600 dark:group-hover:text-indigo-400" : "text-slate-900 dark:text-white"
                    concat(content_tag(:span, title.truncate(60), class: "font-medium #{title_class} truncate"))
                    
                    if item.respond_to?(:status) && item.status.present?
                      concat(render_status_badge(item.status, size: :sm))
                    end
                  end)
                  
                  # Subtitle with extra info
                  subtitle_parts = []
                  subtitle_parts << item.description.to_s.truncate(80) if item.respond_to?(:description) && item.description.present?
                  subtitle_parts << item.tool_key if item.respond_to?(:tool_key) && item.tool_key.present?
                  subtitle_parts << item.role.to_s.humanize if item.respond_to?(:role) && item.role.present?
                  subtitle_parts << item.provider if item.respond_to?(:provider) && item.provider.present?
                  
                  if subtitle_parts.any?
                    concat(content_tag(:p, subtitle_parts.first, class: "text-sm text-slate-500 dark:text-slate-400 mt-0.5 truncate"))
                  end
                end)
                
                # Right: Meta info
                concat(content_tag(:div, class: "flex items-center gap-3 flex-shrink-0 text-xs text-slate-400") do
                  # Type-specific badges
                  if item.respond_to?(:active) || item.respond_to?(:active?)
                    is_active = item.respond_to?(:active?) ? item.active? : item.active
                    concat(content_tag(:span, is_active ? "Active" : "Inactive", 
                      class: is_active ? "px-1.5 py-0.5 rounded bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400" : "px-1.5 py-0.5 rounded bg-slate-100 dark:bg-slate-700 text-slate-500"))
                  end
                  
                  # Duration if available
                  if item.respond_to?(:duration_seconds) && item.duration_seconds.present?
                    concat(content_tag(:span, "#{item.duration_seconds.round(1)}s", class: "font-mono"))
                  elsif item.respond_to?(:duration_ms) && item.duration_ms.present?
                    concat(content_tag(:span, "#{item.duration_ms}ms", class: "font-mono"))
                  end
                  
                  # Timestamp
                  if item.respond_to?(:created_at) && item.created_at
                    concat(content_tag(:span, time_ago_in_words(item.created_at) + " ago"))
                  end
                  
                  # Arrow indicator for links
                  if link_path
                    concat('<svg class="w-4 h-4 text-slate-300 dark:text-slate-600 group-hover:text-indigo-500 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>'.html_safe)
                  end
                end)
              end)
            end))
          end
        end
      end

      # Renders association as a table
      #
      # @param items [Array] Associated records
      # @param section [ShowSectionDefinition] Section definition
      # @return [String] HTML safe table
      def render_association_table(items, section)
        # Smart column detection if not specified
        columns = if section.columns.present?
          section.columns
        else
          detect_table_columns(items.first)
        end
        
        content_tag(:div, class: "overflow-x-auto -mx-6 -mt-1 -mb-6") do
          content_tag(:table, class: "min-w-full divide-y divide-slate-200 dark:divide-slate-700") do
            # Header
            concat(content_tag(:thead, class: "bg-slate-50/50 dark:bg-slate-900/30") do
              content_tag(:tr) do
                columns.each do |col|
                  header = col.to_s.gsub(/_id$/, '').humanize
                  concat(content_tag(:th, header, class: "px-4 py-2.5 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider first:pl-6"))
                end
                if section.link_to.present?
                  concat(content_tag(:th, "", class: "px-4 py-2.5 w-16")) # Actions column
                end
              end
            end)
            
            # Body
            concat(content_tag(:tbody, class: "divide-y divide-slate-200 dark:divide-slate-700") do
              items.each do |item|
                link_path = section.link_to.present? ? build_association_link(item, section) : nil
                row_class = link_path ? "hover:bg-indigo-50/50 dark:hover:bg-indigo-900/10 cursor-pointer group" : "hover:bg-slate-50 dark:hover:bg-slate-900/30"
                
                concat(content_tag(:tr, class: row_class, data: link_path ? { turbo_frame: "_top" } : {}) do
                  columns.each_with_index do |col, idx|
                    value = item.public_send(col) rescue nil
                    formatted = format_table_cell_enhanced(item, col, value, link_path && idx == 0)
                    td_class = idx == 0 ? "px-4 py-3 text-sm first:pl-6" : "px-4 py-3 text-sm"
                    concat(content_tag(:td, formatted, class: td_class))
                  end
                  
                  # Actions
                  if section.link_to.present? && link_path
                    concat(content_tag(:td, class: "px-4 py-3 text-right pr-6") do
                      link_to(link_path, class: "inline-flex items-center text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-indigo-300 text-sm font-medium") do
                        "View".html_safe
                      end
                    end)
                  end
                end)
              end
            end)
          end
        end
      end
      
      # Detects appropriate columns for a table based on record attributes
      #
      # @param item [ActiveRecord::Base] Sample record
      # @return [Array<Symbol>] Column names
      def detect_table_columns(item)
        return [:id, :name, :created_at] unless item
        
        # Priority columns to show
        priority = [:name, :title, :status, :role, :tool_key, :provider, :model]
        # Columns to skip
        skip = [:id, :created_at, :updated_at, :password_digest, :encrypted_password]
        
        attrs = item.attributes.keys.map(&:to_sym)
        
        # Start with priority columns that exist
        selected = priority.select { |c| attrs.include?(c) }
        
        # Add other relevant columns
        attrs.each do |col|
          next if skip.include?(col)
          next if selected.include?(col)
          next if col.to_s.end_with?('_id') # Skip foreign keys, show relations instead
          next if col.to_s.include?('token') || col.to_s.include?('secret')
          next if selected.size >= 5
          
          selected << col
        end
        
        # Always include created_at at the end if space
        selected << :created_at if selected.size < 5 && attrs.include?(:created_at)
        
        selected.take(5)
      end
      
      # Enhanced table cell formatting
      #
      # @param item [ActiveRecord::Base] The record
      # @param column [Symbol] Column name
      # @param value [Object] The value
      # @param is_primary [Boolean] Whether this is the primary/title column
      # @return [String] Formatted value
      def format_table_cell_enhanced(item, column, value, is_primary = false)
        case value
        when nil
          content_tag(:span, "—", class: "text-slate-400")
        when true
          content_tag(:span, class: "inline-flex items-center gap-1") do
            '<svg class="w-4 h-4 text-green-500" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/></svg>'.html_safe
          end
        when false
          content_tag(:span, class: "inline-flex items-center gap-1") do
            '<svg class="w-4 h-4 text-slate-300" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/></svg>'.html_safe
          end
        when Time, DateTime
          content_tag(:span, value.strftime("%b %d, %H:%M"), class: "text-slate-600 dark:text-slate-400")
        when Date
          content_tag(:span, value.strftime("%b %d, %Y"), class: "text-slate-600 dark:text-slate-400")
        when Integer, Float, BigDecimal
          if column.to_s.include?('duration') || column.to_s.include?('latency')
            content_tag(:span, "#{value}ms", class: "font-mono text-slate-600 dark:text-slate-400")
          elsif column.to_s.include?('cost') || column.to_s.include?('cents')
            content_tag(:span, "$#{(value / 100.0).round(4)}", class: "font-mono text-slate-600 dark:text-slate-400")
          elsif column.to_s.include?('token')
            content_tag(:span, number_with_delimiter(value), class: "font-mono text-slate-600 dark:text-slate-400")
          else
            content_tag(:span, number_with_delimiter(value), class: "text-slate-900 dark:text-white")
          end
        when ActiveRecord::Base
          display = value.respond_to?(:name) ? value.name : value.class.name.demodulize
          content_tag(:span, display.to_s.truncate(25), class: "text-slate-600 dark:text-slate-400")
        else
          str = value.to_s
          if column == :status || column.to_s.end_with?('_status')
            render_status_badge(value, size: :sm)
          elsif is_primary
            content_tag(:span, str.truncate(50), class: "font-medium text-slate-900 dark:text-white group-hover:text-indigo-600 dark:group-hover:text-indigo-400")
          else
            content_tag(:span, str.truncate(40), class: "text-slate-900 dark:text-white")
          end
        end
      end

      # Renders association as cards
      #
      # @param items [Array] Associated records
      # @param section [ShowSectionDefinition] Section definition
      # @return [String] HTML safe cards
      def render_association_cards(items, section)
        content_tag(:div, class: "grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1") do
          items.each do |item|
            link_path = section.link_to.present? ? build_association_link(item, section) : nil
            
            card_class = "border border-slate-200 dark:border-slate-700 rounded-lg p-4 transition-all"
            card_class += link_path ? " hover:border-indigo-300 dark:hover:border-indigo-700 hover:shadow-md group cursor-pointer" : " hover:bg-slate-50 dark:hover:bg-slate-900/30"
            
            card_content = capture do
              # Header with title and status
              concat(content_tag(:div, class: "flex items-start justify-between gap-2 mb-2") do
                title = item_display_title(item)
                title_class = link_path ? "font-medium text-slate-900 dark:text-white group-hover:text-indigo-600 dark:group-hover:text-indigo-400" : "font-medium text-slate-900 dark:text-white"
                concat(content_tag(:span, title.truncate(35), class: title_class))
                
                if item.respond_to?(:status) && item.status.present?
                  concat(render_status_badge(item.status, size: :sm))
                end
              end)
              
              # Description or key info
              info_parts = []
              info_parts << item.description.to_s.truncate(80) if item.respond_to?(:description) && item.description.present?
              info_parts << "Tool: #{item.tool_key}" if item.respond_to?(:tool_key) && item.tool_key.present?
              info_parts << "Role: #{item.role.to_s.humanize}" if item.respond_to?(:role) && item.role.present?
              info_parts << "Provider: #{item.provider}" if item.respond_to?(:provider) && item.provider.present?
              
              if info_parts.any?
                concat(content_tag(:p, info_parts.first, class: "text-sm text-slate-500 dark:text-slate-400 mb-3 line-clamp-2"))
              end
              
              # Footer with meta info
              concat(content_tag(:div, class: "flex items-center justify-between text-xs text-slate-400 pt-2 border-t border-slate-100 dark:border-slate-700/50") do
                # Left: timestamp
                if item.respond_to?(:created_at) && item.created_at
                  concat(content_tag(:span, time_ago_in_words(item.created_at) + " ago"))
                end
                
                # Right: additional info or link arrow
                if link_path
                  concat('<svg class="w-4 h-4 text-slate-300 dark:text-slate-600 group-hover:text-indigo-500 group-hover:translate-x-0.5 transition-all" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>'.html_safe)
                elsif item.respond_to?(:active) || item.respond_to?(:active?)
                  is_active = item.respond_to?(:active?) ? item.active? : item.active
                  concat(content_tag(:span, is_active ? "Active" : "Inactive", 
                    class: is_active ? "text-green-600 dark:text-green-400" : "text-slate-400"))
                end
              end)
            end
            
            if link_path
              concat(link_to(card_content, link_path, class: card_class))
            else
              concat(content_tag(:div, card_content, class: card_class))
            end
          end
        end
      end

      # Formats a value for table cell display
      #
      # @param value [Object] The value
      # @return [String] Formatted value
      def format_table_cell(value)
        case value
        when nil
          "—"
        when true, false
          value ? "Yes" : "No"
        when Time, DateTime
          value.strftime("%b %d, %H:%M")
        when Date
          value.strftime("%b %d, %Y")
        when ActiveRecord::Base
          value.respond_to?(:name) ? value.name : "##{value.id}"
        else
          value.to_s.truncate(50)
        end
      end

      # Returns a display title for an item
      #
      # @param item [ActiveRecord::Base] The record
      # @return [String] Display title
      def item_display_title(item)
        return item.name if item.respond_to?(:name) && item.name.present?
        return item.title if item.respond_to?(:title) && item.title.present?
        return item.content.to_s.truncate(50) if item.respond_to?(:content)
        return item.tool_key if item.respond_to?(:tool_key)
        "##{item.id}"
      end

      # Builds a link path for an associated item
      #
      # @param item [ActiveRecord::Base] The record
      # @param section [ShowSectionDefinition] Section definition
      # @return [String, nil] Link path or nil
      def build_association_link(item, section)
        return nil unless section.link_to.present?
        
        begin
          send(section.link_to, item)
        rescue NoMethodError
          nil
        end
      end

      # Renders a status badge
      #
      # @param status [String, Symbol] The status
      # @param size [Symbol] Badge size (:sm, :md)
      # @return [String] HTML safe badge
      def render_status_badge(status, size: :md)
        return content_tag(:span, "—", class: "text-slate-400") if status.blank?
        
        status_str = status.to_s.downcase
        
        colors = case status_str
        when "active", "open", "success", "approved", "completed", "enabled"
          "bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400"
        when "pending", "proposed", "queued", "waiting"
          "bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400"
        when "running", "processing", "in_progress"
          "bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-400"
        when "error", "failed", "rejected", "cancelled"
          "bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400"
        when "inactive", "closed", "disabled", "archived"
          "bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400"
        else
          "bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400"
        end
        
        padding = size == :sm ? "px-1.5 py-0.5 text-xs" : "px-2 py-1 text-xs"
        
        content_tag(:span, status_str.titleize, class: "inline-flex items-center #{padding} rounded-full font-medium #{colors}")
      end

      # Renders a form field based on its configuration
      #
      # @param f [ActionView::Helpers::FormBuilder] Form builder
      # @param field [FieldDefinition] Field definition
      # @param resource [ActiveRecord::Base] The record
      # @return [String] HTML safe form field
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
            when :textarea
              f.text_area(field.name, class: field_class, rows: field.rows || 4, placeholder: field.placeholder, readonly: field.readonly)
            when :url
              f.url_field(field.name, class: field_class, placeholder: field.placeholder, readonly: field.readonly)
            when :email
              f.email_field(field.name, class: field_class, placeholder: field.placeholder, readonly: field.readonly)
            when :number
              f.number_field(field.name, class: field_class, placeholder: field.placeholder, readonly: field.readonly)
            when :toggle
              render_toggle_field(f, field, resource)
            when :select
              collection = field.collection.is_a?(Proc) ? field.collection.call : field.collection
              f.select(field.name, collection, { include_blank: true }, class: field_class, disabled: field.readonly)
            when :searchable_select
              render_searchable_select(f, field, resource)
            when :multi_select, :tags
              render_multi_select(f, field, resource)
            when :image, :attachment
              render_file_upload(f, field, resource)
            when :trix, :rich_text
              f.rich_text_area(field.name, class: "prose dark:prose-invert max-w-none")
            when :markdown
              f.text_area(field.name, class: "#{field_class} font-mono", rows: field.rows || 12, 
                data: { controller: "markdown-editor" },
                placeholder: field.placeholder)
            when :file
              f.file_field(field.name, class: "form-input-file", accept: field.accept)
            when :json
              render("internal/developer/shared/json_editor_field",
                f: f, 
                field: field, 
                resource: resource)
            when :code
              render_code_editor(f, field, resource)
            else
              f.text_field(field.name, class: field_class, placeholder: field.placeholder, readonly: field.readonly)
            end

            concat(field_html)

            if field.help.present?
              concat(content_tag(:p, field.help, class: "mt-1 text-sm text-slate-500 dark:text-slate-400"))
            end

            if resource.errors[field.name].any?
              concat(content_tag(:p, resource.errors[field.name].first, class: "mt-1 text-sm text-red-600 dark:text-red-400"))
            end
          end)
        end
      end

      # Renders a toggle switch field (inline, not taking full width)
      #
      # @param f [ActionView::Helpers::FormBuilder] Form builder
      # @param field [FieldDefinition] Field definition
      # @param resource [ActiveRecord::Base] The record
      # @return [String] HTML safe toggle switch
      def render_toggle_field(f, field, resource)
        checked = !!resource.public_send(field.name)
        param_key = resource.class.model_name.param_key
        
        content_tag(:div, class: "inline-flex items-center gap-3",
                    data: { controller: "toggle-switch" }) do
          # Toggle switch button
          concat(content_tag(:button, type: "button", 
                 class: "relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 dark:focus:ring-offset-slate-800 #{checked ? 'bg-indigo-600' : 'bg-slate-200 dark:bg-slate-700'}",
                 role: "switch",
                 "aria-checked" => checked.to_s,
                 data: { 
                   action: "click->toggle-switch#toggle",
                   toggle_switch_target: "button"
                 },
                 disabled: field.readonly) do
            concat(content_tag(:span, "",
                   class: "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out #{checked ? 'translate-x-5' : 'translate-x-0'}",
                   data: { toggle_switch_target: "thumb" }))
          end)
          
          # Hidden input for form submission
          concat(hidden_field_tag("#{param_key}[#{field.name}]", checked ? "1" : "0",
                 id: "#{param_key}_#{field.name}",
                 data: { toggle_switch_target: "input" }))
          
          # Status label
          concat(content_tag(:span, checked ? "Enabled" : "Disabled",
                 class: "text-sm font-medium text-slate-700 dark:text-slate-300",
                 data: { toggle_switch_target: "label" }))
        end
      end

      # Renders a searchable select field
      #
      # @param f [ActionView::Helpers::FormBuilder] Form builder
      # @param field [FieldDefinition] Field definition
      # @param resource [ActiveRecord::Base] The record
      # @return [String] HTML safe searchable select
      def render_searchable_select(f, field, resource)
        param_key = resource.class.model_name.param_key
        current_value = resource.public_send(field.name)
        
        # Get options - handle Proc, Array, or String (URL)
        collection = field.collection.is_a?(Proc) ? field.collection.call : field.collection
        
        if collection.is_a?(Array)
          options_json = collection.map { |opt| 
            if opt.is_a?(Array)
              { value: opt[1], label: opt[0] }
            else
              { value: opt, label: opt.to_s.humanize }
            end
          }.to_json
        else
          options_json = "[]"
        end
        
        # For display, find the current label
        current_label = if current_value.present? && collection.is_a?(Array)
          match = collection.find { |opt| opt.is_a?(Array) ? opt[1].to_s == current_value.to_s : opt.to_s == current_value.to_s }
          match.is_a?(Array) ? match[0] : match.to_s
        else
          current_value
        end
        
        content_tag(:div, 
          data: { 
            controller: "searchable-select",
            searchable_select_options_value: options_json,
            searchable_select_creatable_value: field.create_url.present?,
            searchable_select_search_url_value: collection.is_a?(String) ? collection : ""
          },
          class: "relative") do
          concat(hidden_field_tag("#{param_key}[#{field.name}]", current_value, 
                 data: { searchable_select_target: "input" }))
          concat(text_field_tag("#{param_key}[#{field.name}]_search", 
                 current_label,
                 class: "form-input w-full",
                 placeholder: field.placeholder || "Search...",
                 autocomplete: "off",
                 data: { 
                   searchable_select_target: "search",
                   action: "input->searchable-select#search focus->searchable-select#open keydown->searchable-select#keydown"
                 }))
          concat(content_tag(:div, "", 
                 class: "absolute z-10 w-full mt-1 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg shadow-lg hidden max-h-60 overflow-y-auto",
                 data: { searchable_select_target: "dropdown" }))
        end
      end

      # Renders a multi-select/tags field
      #
      # @param f [ActionView::Helpers::FormBuilder] Form builder
      # @param field [FieldDefinition] Field definition
      # @param resource [ActiveRecord::Base] The record
      # @return [String] HTML safe multi-select
      def render_multi_select(f, field, resource)
        param_key = resource.class.model_name.param_key
        
        # Get current values
        current_values = if resource.respond_to?("#{field.name}_list")
          resource.public_send("#{field.name}_list")
        elsif resource.respond_to?(field.name)
          Array.wrap(resource.public_send(field.name))
        else
          []
        end
        
        # Get available options
        options = if field.collection.is_a?(Proc)
          field.collection.call
        elsif field.collection.is_a?(Array)
          field.collection
        else
          []
        end
        
        content_tag(:div, 
          data: { 
            controller: "tag-select",
            tag_select_creatable_value: field.create_url.present? || field.type == :tags
          },
          class: "space-y-2") do
          
          # Hidden field for form submission
          field_name = field.type == :tags ? "tag_list" : "#{field.name}[]"
          concat(hidden_field_tag("#{param_key}[#{field_name}]", "", id: nil))
          
          # Selected tags display
          concat(content_tag(:div, 
                 class: "flex flex-wrap gap-2 min-h-[2.5rem] p-2 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-lg",
                 data: { tag_select_target: "tags" }) do
            current_values.each do |val|
              concat(content_tag(:span, 
                     class: "inline-flex items-center gap-1 px-2 py-1 bg-indigo-100 dark:bg-indigo-900/50 text-indigo-700 dark:text-indigo-300 rounded text-sm") do
                concat(val.to_s)
                concat(hidden_field_tag("#{param_key}[#{field_name}]", val, id: nil))
                concat(button_tag("×", 
                       type: "button",
                       class: "text-indigo-500 hover:text-indigo-700 font-bold",
                       data: { action: "tag-select#remove" }))
              end)
            end
            
            # Input for adding new tags
            concat(text_field_tag(nil, "",
                   class: "flex-1 min-w-[120px] border-none focus:outline-none focus:ring-0 bg-transparent text-sm",
                   placeholder: field.placeholder || "Add tag...",
                   autocomplete: "off",
                   data: { 
                     tag_select_target: "input",
                     action: "keydown->tag-select#keydown input->tag-select#search"
                   }))
          end)
          
          # Suggestions dropdown
          if options.any?
            concat(content_tag(:div, 
                   class: "hidden border border-slate-200 dark:border-slate-700 rounded-lg bg-white dark:bg-slate-800 shadow-lg max-h-48 overflow-y-auto",
                   data: { tag_select_target: "dropdown" }) do
              options.each do |opt|
                label, value = opt.is_a?(Array) ? [opt[0], opt[1]] : [opt, opt]
                concat(content_tag(:button, label,
                       type: "button",
                       class: "block w-full text-left px-3 py-2 text-sm hover:bg-slate-100 dark:hover:bg-slate-700",
                       data: { 
                         action: "tag-select#select",
                         value: value
                       }))
              end
            end)
          end
        end
      end

      # Renders a file upload field with preview
      #
      # @param f [ActionView::Helpers::FormBuilder] Form builder
      # @param field [FieldDefinition] Field definition
      # @param resource [ActiveRecord::Base] The record
      # @return [String] HTML safe file upload
      def render_file_upload(f, field, resource)
        attachment = resource.respond_to?(field.name) ? resource.public_send(field.name) : nil
        has_attachment = attachment.respond_to?(:attached?) && attachment.attached?
        
        is_image = field.type == :image || 
                   (field.accept.present? && field.accept.include?("image"))
        
        # Build existing URL for preview if available
        existing_url = has_attachment && is_image ? url_for(attachment.variant(resize_to_limit: [300, 300])) : nil
        
        content_tag(:div, 
          data: { 
            controller: "file-upload",
            file_upload_accept_value: field.accept || (is_image ? "image/*" : "*/*"),
            file_upload_preview_value: field.type == :image,
            file_upload_existing_url_value: existing_url
          },
          class: "space-y-3") do
          
          # Current file preview
          if has_attachment && is_image
            concat(content_tag(:div, class: "relative inline-block") do
              concat(image_tag(existing_url,
                     class: "max-w-[200px] max-h-[150px] rounded-lg border border-slate-200 dark:border-slate-700 object-cover",
                     data: { file_upload_target: "imagePreview" }))
              concat(button_tag("×", type: "button",
                     class: "absolute -top-2 -right-2 w-6 h-6 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center text-sm",
                     data: { 
                       file_upload_target: "removeButton",
                       action: "file-upload#remove" 
                     }))
            end)
          elsif has_attachment
            concat(content_tag(:div, 
                   class: "flex items-center gap-2 p-3 bg-slate-50 dark:bg-slate-900 rounded-lg",
                   data: { file_upload_target: "filename" }) do
              concat('<svg class="w-5 h-5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>'.html_safe)
              concat(content_tag(:span, attachment.filename.to_s, class: "text-sm font-medium text-slate-600 dark:text-slate-300"))
              concat(content_tag(:span, "(#{number_to_human_size(attachment.byte_size)})", class: "text-xs text-slate-400"))
            end)
          else
            # Hidden image preview for new uploads
            concat(image_tag("", 
                   class: "hidden max-w-[200px] max-h-[150px] rounded-lg border border-slate-200 dark:border-slate-700 object-cover",
                   data: { file_upload_target: "imagePreview" }))
            concat(content_tag(:div, "", 
                   class: "hidden",
                   data: { file_upload_target: "filename" }))
          end
          
          # Dropzone / Upload area
          concat(content_tag(:div, 
                 class: "relative border-2 border-dashed border-slate-300 dark:border-slate-600 rounded-lg hover:border-indigo-400 dark:hover:border-indigo-500 transition-colors",
                 data: { file_upload_target: "dropzone" }) do
            # Hidden file input
            concat(f.file_field(field.name, 
                   class: "sr-only",
                   id: "#{field.name}_input",
                   accept: field.accept || (is_image ? "image/*" : nil),
                   data: { 
                     file_upload_target: "input",
                     action: "change->file-upload#preview" 
                   }))
            
            # Styled upload label
            concat(content_tag(:label, 
                   for: "#{field.name}_input",
                   class: "flex flex-col items-center justify-center w-full py-6 cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-900/50 rounded-lg transition-colors") do
              concat('<svg class="w-8 h-8 text-slate-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/></svg>'.html_safe)
              concat(content_tag(:span, "Click to upload or drag and drop", class: "text-sm text-slate-500 dark:text-slate-400"))
              if is_image
                concat(content_tag(:span, "PNG, JPG, WebP up to 10MB", class: "text-xs text-slate-400 mt-1"))
              elsif field.accept.present?
                concat(content_tag(:span, field.accept.gsub(",", ", "), class: "text-xs text-slate-400 mt-1"))
              end
            end)
          end)
          
          # Progress indicator (hidden by default)
          concat(content_tag(:div, "", 
                 class: "hidden",
                 data: { file_upload_target: "progress" }))
        end
      end

      # Renders turn messages preview (for assistant turns)
      #
      # @param resource [ActiveRecord::Base] The turn record
      # @return [String] HTML safe messages preview
      def render_turn_messages_preview(resource)
        user_msg = resource.respond_to?(:user_message) ? resource.user_message : nil
        asst_msg = resource.respond_to?(:assistant_message) ? resource.assistant_message : nil
        
        content_tag(:div, class: "space-y-4") do
          # User message
          if user_msg
            concat(content_tag(:div, class: "rounded-lg border p-4 bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800") do
              concat(content_tag(:div, class: "flex items-center gap-2 mb-2") do
                concat('<svg class="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>'.html_safe)
                concat(content_tag(:span, "User", class: "text-sm font-medium text-slate-700 dark:text-slate-200"))
              end)
              concat(content_tag(:div, simple_format(h(user_msg.content.to_s)), class: "prose dark:prose-invert prose-sm max-w-none"))
            end)
          end
          
          # Assistant message
          if asst_msg
            concat(content_tag(:div, class: "rounded-lg border p-4 bg-emerald-50 dark:bg-emerald-900/20 border-emerald-200 dark:border-emerald-800") do
              concat(content_tag(:div, class: "flex items-center gap-2 mb-2") do
                concat('<svg class="w-4 h-4 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"/></svg>'.html_safe)
                concat(content_tag(:span, "Assistant", class: "text-sm font-medium text-slate-700 dark:text-slate-200"))
              end)
              concat(content_tag(:div, simple_format(h(asst_msg.content.to_s)), class: "prose dark:prose-invert prose-sm max-w-none"))
            end)
          end
          
          unless user_msg || asst_msg
            concat(content_tag(:p, "No messages found", class: "text-slate-400 italic text-sm"))
          end
        end
      end

      # Renders a code editor field
      #
      # @param f [ActionView::Helpers::FormBuilder] Form builder
      # @param field [FieldDefinition] Field definition
      # @param resource [ActiveRecord::Base] The record
      # @return [String] HTML safe code editor
      def render_code_editor(f, field, resource)
        content_tag(:div, class: "relative", data: { controller: "code-editor" }) do
          f.text_area(field.name, 
            class: "w-full font-mono text-sm bg-slate-900 text-slate-100 p-4 rounded-lg border border-slate-700 focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500",
            rows: field.rows || 12,
            placeholder: field.placeholder,
            data: { code_editor_target: "textarea" })
        end
      end
    end
  end
end
