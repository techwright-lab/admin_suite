# frozen_string_literal: true

module AdminSuite
  # Helper methods for the Admin Suite engine UI.
  #
  # This is intentionally very close to the `/internal/developer` helper so we can
  # keep both UIs side-by-side and compare behavior while migrating.
  module BaseHelper
    include AdminSuite::IconHelper
    include AdminSuite::PanelsHelper
    include AdminSuite::ThemeHelper
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


    include AdminSuite::UI::ShowValueFormatter
    include AdminSuite::UI::FormFieldRenderer

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
        value = record.public_send(column.name) rescue "—"
        if active_record_base?(value)
          render_association_value(value)
        else
          # `rescue "—"` above only fires on an exception; a genuinely nil
          # attribute reaches here untouched and used to render as an empty
          # cell. Every other surface in the gem (`format_table_cell`,
          # `render_association_value`'s own rescues) already shows "—" for
          # nil, so this closes the one place that didn't -- including a
          # nil `belongs_to` value, which Task 3 deliberately left alone
          # because this task owns it.
          value.nil? ? "—" : value
        end
      end
    end

    # Maps a column's `align:` DSL option to a literal Tailwind class.
    #
    # `align` is resource-author-supplied, not end-user input, but it's
    # still an arbitrary value handed to us from outside this method, so
    # this follows the same precedent as the stat panel's `color` mapping
    # (`app/views/admin_suite/panels/_stat.html.erb`) and the dashboard
    # row's `span` clamp (`panels_helper.rb#render_panel`): a closed
    # `case`/`else` over known values, never `"text-#{align}"` string
    # interpolation. Dynamic Tailwind class names are invisible to the
    # content scanner (unstyled in production) even when they happen to be
    # spelled correctly, and an unrecognized or malformed `align:` here
    # must degrade to no alignment class rather than emit a broken one.
    #
    # @param align [Symbol, String, nil]
    # @return [String]
    def column_align_class(align)
      case align.respond_to?(:to_sym) ? align.to_sym : align
      when :right then "text-right"
      when :center then "text-center"
      when :left then "text-left"
      else ""
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

    def render_custom_section(resource, render_type, options = {})
      key = render_type.to_sym

      legacy_proc = AdminSuite.config.custom_renderers[key]
      if legacy_proc
        AdminSuite::LegacyCustomRendererProcs.warn_once(key)
        return legacy_proc.call(resource, self)
      end

      # Precedence, after the legacy proc above (unchanged, Task 3 has tests
      # pinning that): a host's explicit registration, then a host renderer
      # class, then the gem's own defaults (built-ins + the deprecated four
      # Gleania renderers). Checking the gem defaults last means a host that
      # defines `Admin::Renderers::<Key>Renderer` -- exactly the migration
      # path the deprecation warnings recommend -- actually takes effect
      # instead of being silently shadowed by the gem's boot-time
      # registrations (see `RendererRegistry`).
      klass = AdminSuite::RendererRegistry.lookup(key) ||
        host_renderer_class(key) ||
        AdminSuite::RendererRegistry.lookup_default(key)
      return klass.new(resource, self, options).render if klass

      content_tag(:p, "Unknown render type: #{render_type}", class: "text-slate-500 italic")
    end

    # Resolves `Admin::Renderers::<Key>Renderer` in the host app, if defined.
    def host_renderer_class(key)
      "Admin::Renderers::#{key.to_s.camelize}Renderer".safe_constantize
    end

    # A bare `object.is_a?(ActiveRecord::Base)` crashes with `NameError` in a
    # host without ActiveRecord loaded (this gem's own reference DB-free
    # configuration among them) -- not masking, since it isn't inside a
    # rescue, just a plain 500. Same idiom already used by
    # `AdminSuite::UI::ShowFormatterRegistry` (`if defined?(ActiveRecord::Base)`).
    #
    # @param object [Object]
    # @return [Boolean]
    def active_record_base?(object)
      defined?(ActiveRecord::Base) && object.is_a?(ActiveRecord::Base)
    end

    def auto_admin_suite_path_for(item)
      return nil unless active_record_base?(item)

      resource = admin_suite_resource_for(item.class)
      return nil unless resource&.portal_name && resource.respond_to?(:resource_name_plural)

      resource_path(portal: resource.portal_name, resource_name: resource.resource_name_plural, id: item.to_param)
    rescue StandardError
      nil
    end

    # Memoized per-request (the helper is mixed into a view instance created
    # fresh per request) resource-class lookup. Before this, every rendered
    # association value re-ran `ensure_admin_resources_loaded_for!`'s
    # `registered_resources.any?` scan *plus* a `registered_resources.find`
    # scan -- both full linear scans of the registry (28-38 resources in the
    # real hosts) -- once per rendered row. Keying the memo on the model
    # class (not the item's identity) means a page with N rows of the same
    # class costs one lookup, not N.
    #
    # @param model_class [Class]
    # @return [Class, nil] the registered `Admin::Base::Resource` subclass, if any
    def admin_suite_resource_for(model_class)
      @admin_suite_resource_for ||= {}
      return @admin_suite_resource_for[model_class] if @admin_suite_resource_for.key?(model_class)

      ensure_admin_resources_loaded_for!(model_class)
      @admin_suite_resource_for[model_class] = Admin::Base::Resource.registered_resources.find { |r| r.model_class == model_class }
    end

    def ensure_admin_resources_loaded_for!(model_class)
      already_loaded = Admin::Base::Resource.registered_resources.any? { |r| r.model_class == model_class }
      return if already_loaded

      AdminSuite::DefinitionLoader.load!(:resources)
    end

    # ---- show page sections / associations ----
    #
    # For parity, we keep the same section rendering and association displays used by
    # `/internal/developer`. This is intentionally "UI heavy".

    def render_show_section(resource, section, position = :main)
      is_association = section.association.present? && !active_record_base?(resource.public_send(section.association)) rescue false

      content_tag(:div, class: "bg-white rounded-xl border border-slate-200 overflow-hidden") do
        header_padding = position == :sidebar ? "px-4 py-2.5" : "px-6 py-3"
        header_text_size = position == :sidebar ? "text-sm" : ""
        header_border = is_association ? "" : "border-b border-slate-200"

        concat(content_tag(:div, class: "#{header_padding} #{header_border} bg-slate-50 flex items-center justify-between") do
          concat(content_tag(:h3, section.title, class: "font-medium text-slate-900 #{header_text_size}"))

          if section.association.present?
            assoc = resource.public_send(section.association) rescue nil
            if assoc && !active_record_base?(assoc)
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
            render_custom_section(resource, section.render, section.options || {})
          elsif section.association.present?
            render_association_section(resource, section)
          elsif section.fields.any?
            if position == :sidebar
              render_sidebar_fields(resource, section.fields, hide_blank: section.hide_blank)
            else
              render_main_fields(resource, section.fields, hide_blank: section.hide_blank)
            end
          else
            content_tag(:p, "No content", class: "text-slate-400 italic text-sm")
          end
        end)
      end
    end

    def render_sidebar_fields(resource, fields, hide_blank: false)
      content_tag(:div, class: "space-y-3") do
        fields.each do |field_name|
          value = resource.public_send(field_name) rescue nil
          next if hide_blank && show_value_blank?(value)

          if attached_file_value?(value)
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

    def render_main_fields(resource, fields, hide_blank: false)
      content_tag(:dl, class: "space-y-6") do
        fields.each do |field_name|
          # Only re-read the value (and only when `hide_blank` is actually
          # on) so a plain `field :foo` row with no `hide_blank:` costs
          # exactly what it cost before this option existed --
          # `format_show_value` re-reads the value itself below regardless.
          if hide_blank
            value = resource.public_send(field_name) rescue nil
            next if show_value_blank?(value)
          end

          concat(content_tag(:div) do
            concat(content_tag(:dt, field_name.to_s.humanize, class: "text-sm font-medium text-slate-500 mb-2"))
            concat(content_tag(:dd, class: "text-sm text-slate-900") { format_show_value(resource, field_name) })
          end)
        end
      end
    end

    # Whether `resource.public_send(field_name)` should be omitted entirely
    # from a `hide_blank: true` show panel.
    #
    # Deliberately not `value.blank?`: `false.blank?` is `true` in Ruby, and
    # `false` renders as a real, meaningful grey "No" toggle icon today (see
    # `ShowFormatterRegistry`'s `FalseClass` handler) -- hiding it would
    # erase a real signal, not absence of one. Same reasoning for `0` and
    # `0.0`: neither responds to `:empty?`, so both are kept. A
    # whitespace-only string (`"   "`) is also kept -- `String#empty?`
    # checks length, not content, and this option only claims to hide
    # values with *zero* content, not "content a human would consider
    # meaningless."
    #
    # @param value [Object]
    # @return [Boolean]
    def show_value_blank?(value)
      value.nil? || (value.respond_to?(:empty?) && value.empty?)
    end
    private :show_value_blank?

    # True for an `ActiveStorage::Attached::One`/`::Many` proxy -- guarded
    # with `defined?` because the host (and this gem's own dummy test app)
    # may not load ActiveStorage at all.
    #
    # @param value [Object]
    # @return [Boolean]
    def attached_file_value?(value)
      (defined?(ActiveStorage::Attached::One) && value.is_a?(ActiveStorage::Attached::One)) ||
        (defined?(ActiveStorage::Attached::Many) && value.is_a?(ActiveStorage::Attached::Many))
    end
    private :attached_file_value?

    # ---- association rendering ----
    def render_association_section(resource, section)
      associated = resource.public_send(section.association) rescue nil
      return content_tag(:p, "None found", class: "text-slate-400 italic text-sm") if associated.nil?

      is_single = !associated.respond_to?(:to_a) || active_record_base?(associated)
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
        concat(render("admin_suite/shared/pagination", pagy: pagy, page_param: association_page_param(section))) if pagy
      end
    end

    def association_page_param(section) = "#{section.association}_page"

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
      else
        # A `when ActiveRecord::Base` clause would evaluate that constant
        # reference unconditionally (crashing in a host without ActiveRecord
        # loaded), so this branch is checked explicitly via the predicate
        # instead of folded into the `case`.
        return render_association_value(value) if active_record_base?(value)

        value.to_s.truncate(50)
      end
    end

    # Renders a `belongs_to`-shaped association value (typically reached via
    # `render_column_value`'s fallback branch or `format_table_cell`'s AR
    # branch) as its display title, wrapped in a link to the record's own
    # admin page when one resolves -- never the bare `#<Company:0x...>` that
    # ERB's implicit `to_s` would otherwise produce for an AR object, and
    # never the indigo-styled-but-unlinked plain text `format_table_cell`
    # used to render on its own.
    #
    # `item_display_title` can raise on a host record whose `name`/`title`
    # method blows up, and `auto_admin_suite_path_for` already swallows its
    # own errors (unpersisted records, no registered resource, etc.) -- but
    # this wraps the whole thing anyway so one bad row degrades to a plain
    # dash instead of 500ing the entire index or show page.
    #
    # @param value [ActiveRecord::Base]
    # @return [String, ActiveSupport::SafeBuffer]
    def render_association_value(value)
      title = begin
        item_display_title(value).to_s
      rescue StandardError
        "—"
      end

      path = auto_admin_suite_path_for(value)
      path ? link_to(title, path, class: "text-indigo-600 hover:underline") : title
    rescue StandardError
      "—"
    end
    private :render_association_value

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

    # Resolves the default search URL for a `searchable_select` field
    # declared with `resource:` (e.g. `field :company_id,
    # type: :searchable_select, resource: :companies`), so it can reach the
    # gem's own search endpoint (`ResourcesController#search`) without the
    # host wiring up a `collection:` URL by hand. A String `collection:`
    # option always takes precedence over this -- see `render_searchable_select`.
    #
    # Looks up the resource by its plural (or singular) resource name among
    # `Admin::Base::Resource.registered_resources`; returns nil (never raises)
    # when the key is blank, unregistered, or has no `portal_name` to route
    # through, so a typo'd `resource:` degrades to "no remote search" rather
    # than a 500 on the very page meant to render a form.
    #
    # @param resource_key [Symbol, String, nil]
    # @return [String, nil]
    def admin_suite_search_url_for(resource_key)
      return nil if resource_key.blank?

      AdminSuite::DefinitionLoader.load!(:resources)
      key = resource_key.to_s
      target = Admin::Base::Resource.registered_resources.find do |r|
        r.resource_name_plural == key || r.resource_name == key
      end
      return nil unless target&.portal_name

      search_resources_path(portal: target.portal_name, resource_name: target.resource_name_plural)
    rescue StandardError => e
      Rails.logger&.warn(
        "AdminSuite: resolving the search URL for `resource: #{resource_key.inspect}` raised " \
        "#{e.class}: #{e.message}; rendering the field with no remote search."
      )
      nil
    end

    def render_searchable_select(_f, field, resource)
      param_key = resource.class.model_name.param_key
      current_value = resource.public_send(field.name)
      collection = field.collection.is_a?(Proc) ? field.collection.call : field.collection
      # A String `collection:` is an explicit search-URL override and always
      # wins (unchanged host behavior); otherwise fall back to the field's
      # `resource:` option resolved via `admin_suite_search_url_for`.
      search_url = collection.is_a?(String) ? collection : admin_suite_search_url_for(field.resource).to_s

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
          "admin-suite--searchable-select-search-url-value": search_url,
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

    def render_dependent_searchable_select(_f, field, resource)
      param_key = resource.class.model_name.param_key
      current_value = resource.public_send(field.name)
      collection = field.collection.is_a?(Proc) ? field.collection.call : field.collection

      # Collection format: [[label, value, group], ...] — triples with group for filtering
      all_options_json = if collection.is_a?(Array)
        collection.map { |opt|
          if opt.is_a?(Array) && opt.size >= 3
            { value: opt[1], label: opt[0], group: opt[2] }
          elsif opt.is_a?(Array)
            { value: opt[1], label: opt[0] }
          else
            { value: opt, label: opt.to_s.humanize }
          end
        }.to_json
      else
        "[]"
      end

      parent_selector = if field.parent_field
        "[name=\"#{param_key}[#{field.parent_field}]\"]"
      else
        ""
      end

      current_label = if current_value.present? && collection.is_a?(Array)
        match = collection.find { |opt| opt.is_a?(Array) ? opt[1].to_s == current_value.to_s : opt.to_s == current_value.to_s }
        match.is_a?(Array) ? match[0] : match.to_s
      else
        current_value
      end

      content_tag(:div,
        data: {
          controller: "admin-suite--dependent-searchable-select",
          "admin-suite--dependent-searchable-select-all-options-value": all_options_json,
          "admin-suite--dependent-searchable-select-parent-selector-value": parent_selector
        },
        class: "relative") do
        concat(hidden_field_tag("#{param_key}[#{field.name}]", current_value,
          data: { "admin-suite--dependent-searchable-select-target": "input" }))
        concat(text_field_tag(nil, current_label,
          class: "form-input w-full",
          placeholder: field.placeholder || "Search...",
          autocomplete: "off",
          data: {
            "admin-suite--dependent-searchable-select-target": "search",
            action: "input->admin-suite--dependent-searchable-select#search focus->admin-suite--dependent-searchable-select#open keydown->admin-suite--dependent-searchable-select#keydown"
          }))
        concat(content_tag(:div, "",
          class: "absolute z-40 w-full mt-1 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg shadow-lg hidden max-h-60 overflow-y-auto",
          data: { "admin-suite--dependent-searchable-select-target": "dropdown" }))
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

      field_name =
        if field.type == :tags
          name_str = field.name.to_s
          if name_str.end_with?("_list")
            field.name
          elsif resource.class.method_defined?("#{name_str}_list")
            :"#{name_str}_list"
          else
            :tag_list
          end
        else
          field.name
        end
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
