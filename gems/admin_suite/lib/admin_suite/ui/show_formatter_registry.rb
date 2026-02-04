# frozen_string_literal: true

module AdminSuite
  module UI
    module ShowFormatterRegistry
      class << self
        def class_handlers
          @class_handlers ||= {}
        end

        def default_handler
          @default_handler
        end

        def register_class(klass, &block)
          class_handlers[klass] = block
        end

        def register_default(&block)
          @default_handler = block
        end

        def format(value, view:, record:, field_name:)
          handler = class_handlers.find { |klass, _| value.is_a?(klass) }&.last
          handler ||= default_handler
          return nil unless handler

          handler.call(value, view, record, field_name)
        end
      end
    end
  end
end

# ---- default show formatters ----
AdminSuite::UI::ShowFormatterRegistry.register_class(NilClass) do |_value, view, _record, _field|
  view.content_tag(:span, "—", class: "text-slate-400")
end

AdminSuite::UI::ShowFormatterRegistry.register_class(TrueClass) do |_value, view, _record, _field|
  view.content_tag(:span, class: "inline-flex items-center gap-1") do
    view.concat(view.admin_suite_icon("check-circle-2", class: "w-4 h-4 text-green-500"))
    view.concat(view.content_tag(:span, "Yes", class: "text-green-600 dark:text-green-400 font-medium"))
  end
end

AdminSuite::UI::ShowFormatterRegistry.register_class(FalseClass) do |_value, view, _record, _field|
  view.content_tag(:span, class: "inline-flex items-center gap-1") do
    view.concat(view.admin_suite_icon("x-circle", class: "w-4 h-4 text-slate-400"))
    view.concat(view.content_tag(:span, "No", class: "text-slate-500"))
  end
end

AdminSuite::UI::ShowFormatterRegistry.register_class(Time) do |value, view, _record, _field|
  view.content_tag(:span, class: "inline-flex items-center gap-2") do
    view.concat(view.content_tag(:span, value.strftime("%B %d, %Y at %H:%M"), class: "font-medium"))
    view.concat(view.content_tag(:span, "(#{view.time_ago_in_words(value)} ago)", class: "text-slate-500 dark:text-slate-400 text-xs"))
  end
end

AdminSuite::UI::ShowFormatterRegistry.register_class(DateTime) do |value, view, _record, _field|
  view.content_tag(:span, class: "inline-flex items-center gap-2") do
    view.concat(view.content_tag(:span, value.strftime("%B %d, %Y at %H:%M"), class: "font-medium"))
    view.concat(view.content_tag(:span, "(#{view.time_ago_in_words(value)} ago)", class: "text-slate-500 dark:text-slate-400 text-xs"))
  end
end

AdminSuite::UI::ShowFormatterRegistry.register_class(Date) do |value, _view, _record, _field|
  value.strftime("%B %d, %Y")
end

if defined?(ActiveRecord::Base)
  AdminSuite::UI::ShowFormatterRegistry.register_class(ActiveRecord::Base) do |value, view, _record, _field|
    link_text = value.respond_to?(:name) ? value.name : "#{value.class.name} ##{value.id}"
    view.content_tag(:span, link_text, class: "text-indigo-600 dark:text-indigo-400")
  end
end

AdminSuite::UI::ShowFormatterRegistry.register_class(Hash) do |value, view, _record, _field|
  view.render_json_block(value)
end

AdminSuite::UI::ShowFormatterRegistry.register_class(Array) do |value, view, _record, _field|
  if value.empty?
    view.content_tag(:span, "Empty array", class: "text-slate-400 italic")
  elsif value.first.is_a?(Hash)
    view.render_json_block(value)
  else
    view.content_tag(:div, class: "flex flex-wrap gap-1") do
      value.each do |item|
        view.concat(view.content_tag(:span, item.to_s, class: "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-300"))
      end
    end
  end
end

AdminSuite::UI::ShowFormatterRegistry.register_class(Integer) do |value, view, _record, _field|
  view.content_tag(:span, view.number_with_delimiter(value), class: "font-mono")
end

AdminSuite::UI::ShowFormatterRegistry.register_class(Float) do |value, view, _record, _field|
  view.content_tag(:span, view.number_with_delimiter(value), class: "font-mono")
end

AdminSuite::UI::ShowFormatterRegistry.register_default do |value, view, _record, field_name|
  value_str = value.to_s

  if value_str.start_with?("{", "[") && value_str.length > 10
    begin
      parsed = JSON.parse(value_str)
      view.render_json_block(parsed)
    rescue JSON::ParserError
      view.render_text_block(value_str)
    end
  elsif value_str.include?("\n") || value_str.length > 200
    view.render_text_block(value_str, view.detect_language(field_name, value_str))
  else
    value_str
  end
end
