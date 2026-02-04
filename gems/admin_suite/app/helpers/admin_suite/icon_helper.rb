# frozen_string_literal: true

module AdminSuite
  module IconHelper
    # Renders an icon for AdminSuite using the configured renderer.
    #
    # Default behavior uses lucide-rails (lucide_icon) if available.
    # Back-compat: if `name` looks like raw SVG markup, it is returned as HTML safe.
    #
    # @param name [String, Symbol] icon name (e.g. "settings") OR raw svg string
    # @param opts [Hash] passed to the underlying renderer (e.g. class:, stroke_width:)
    # @return [ActiveSupport::SafeBuffer, String]
    def admin_suite_icon(name, **opts)
      return "".html_safe if name.blank?

      raw = name.to_s
      if raw.lstrip.start_with?("<svg")
        return raw.html_safe
      end

      renderer = AdminSuite.config.icon_renderer
      return renderer.call(raw, self, **opts) if renderer.respond_to?(:call)

      if respond_to?(:lucide_icon)
        default_class = "w-4 h-4"
        return lucide_icon(raw, **opts.merge(class: [ default_class, opts[:class] ].compact.join(" ")))
      end

      # Safety fallback if lucide-rails isn't available in the host app for any reason.
      content_tag(:span, "", class: opts[:class] || "inline-block w-4 h-4", title: raw)
    end
  end
end
