# frozen_string_literal: true

module AdminSuite
  # Base class for panel renderers.
  #
  # Host apps subclass this in `app/admin/renderers/*.rb` and reference it
  # from a show panel:
  #
  #   panel :costs, title: "Provider Costs", render: :provider_costs
  #   # => Admin::Renderers::ProviderCostsRenderer
  #
  # Subclasses implement #render and may use the primitives below rather than
  # hand-building markup, so panels stay visually consistent with the rest of
  # the admin UI.
  class Renderer
    attr_reader :record, :view, :options

    # @param record [Object] the resource being rendered
    # @param view [ActionView::Base] the calling view/helper context
    # @param options [Hash] leftover panel DSL options (e.g. `source:`,
    #   `columns:`, `empty:`, `language:`) forwarded from `ShowSectionDefinition#options`.
    #   Defaults to `{}` so Task 3's two-arg construction keeps working.
    def initialize(record, view, options = {})
      @record = record
      @view = view
      @options = options || {}
    end

    # @return [String] HTML-safe markup for the panel body
    def render
      raise NotImplementedError, "#{self.class.name} must implement #render"
    end

    private

    def content_tag(...) = view.content_tag(...)
    def safe_join(...) = view.safe_join(...)
    def h(...) = view.h(...)

    # Resolves the panel's `source:` option: a Proc called with the record
    # (or with no args, if it takes none), a Symbol/String sent to the
    # record, or a literal value. Falls back to `default` when no `source:`
    # option was given.
    def source_value(default = nil)
      source = options[:source]
      case source
      when Proc then source.arity.zero? ? source.call : source.call(record)
      when Symbol, String then record.public_send(source)
      when nil then default
      else source
      end
    end

    # Pretty-printed JSON in a copyable dark block.
    #
    # `BaseHelper#render_json_block` takes only the data (no title), so a
    # title, when given, is rendered as a small heading above the block
    # rather than threaded into the helper.
    def json_block(value, title: nil)
      block = view.render_json_block(value)
      return block if title.blank?

      safe_join([
        content_tag(:h4, title, class: "text-sm font-medium text-slate-500 mb-2"),
        block
      ])
    end

    # Syntax-highlighted text block.
    def code_block(text, language: nil)
      view.render_text_block(text, language)
    end

    # @param pairs [Array<Array(String, Object)>] label/value pairs
    def key_value_list(pairs)
      rows = pairs.map do |label, value|
        content_tag(:div, class: "flex justify-between gap-4 py-2 border-b border-slate-100 last:border-0") do
          safe_join([
            content_tag(:span, label.to_s, class: "text-sm text-slate-500"),
            content_tag(:span, value.to_s, class: "text-sm text-slate-900 text-right")
          ])
        end
      end
      content_tag(:div, safe_join(rows))
    end

    # @param rows [Array<Hash>] row hashes keyed by the column names
    # @param columns [Array<Symbol>] column order
    # @param empty [String, nil] message when rows are blank
    def data_table(rows, columns:, empty: nil)
      return empty_state(empty || "None found.") if rows.blank?

      header = content_tag(:tr, safe_join(columns.map { |c|
        content_tag(:th, c.to_s.humanize, class: "text-left text-xs font-medium text-slate-400 uppercase tracking-wider pb-2")
      }))

      body = rows.map do |row|
        content_tag(:tr, safe_join(columns.map { |c|
          content_tag(:td, row[c].to_s, class: "py-2 text-sm text-slate-900 border-t border-slate-100")
        }))
      end

      content_tag(:div, class: "overflow-x-auto") do
        content_tag(:table, safe_join([ content_tag(:thead, header), content_tag(:tbody, safe_join(body)) ]), class: "w-full")
      end
    end

    # `BaseHelper#render_label_badge` takes `color:` as a keyword argument
    # (not positional), so it is passed through as one here.
    def badge(text, color: :slate)
      view.render_label_badge(text, color: color)
    end

    def empty_state(message)
      content_tag(:p, message, class: "text-slate-500 italic text-sm")
    end
  end
end
