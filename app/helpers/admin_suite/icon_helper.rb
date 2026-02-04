# frozen_string_literal: true

module AdminSuite
  module IconHelper
    # Renders an icon for AdminSuite using the configured renderer.
    #
    # Default behavior uses lucide-rails (LucideRails::IconProvider) if available.
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

      # lucide-rails provides stripped SVG paths via IconProvider; we wrap them.
      if defined?(::LucideRails::IconProvider)
        default_class = "w-4 h-4"
        css_class = [ default_class, opts[:class] ].compact.join(" ")
        stroke_width = opts.fetch(:stroke_width, 2)
        title = opts[:title]

        begin
          inner = ::LucideRails::IconProvider.icon(raw)
        rescue ArgumentError
          inner = nil
        end

        if inner.present?
          return content_tag(
            :svg,
            (title.present? ? content_tag(:title, title) + inner.html_safe : inner.html_safe),
            class: css_class,
            xmlns: "http://www.w3.org/2000/svg",
            width: "24",
            height: "24",
            viewBox: "0 0 24 24",
            fill: "none",
            stroke: "currentColor",
            "stroke-width" => stroke_width,
            "stroke-linecap" => "round",
            "stroke-linejoin" => "round",
            "aria-hidden" => "true",
            focusable: "false"
          )
        end
      end

      # Safety fallback if lucide-rails isn't available in the host app for any reason.
      content_tag(:span, "", class: opts[:class] || "inline-block w-4 h-4", title: raw)
    end
  end
end
