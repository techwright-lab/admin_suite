# frozen_string_literal: true

module AdminSuite
  module ThemeHelper
    def admin_suite_theme
      (AdminSuite.config.theme || {}).symbolize_keys
    rescue StandardError
      {}
    end

    def theme_primary
      admin_suite_theme[:primary]
    end

    def theme_secondary
      admin_suite_theme[:secondary]
    end

    # Returns a <style> tag that scopes theme variables to AdminSuite.
    #
    # This is the core of engine-build mode theming: UI classes stay static
    # (no `bg-#{...}`), and color changes are driven by CSS variables.
    def admin_suite_theme_style_tag
      theme = admin_suite_theme

      primary = theme[:primary]
      secondary = theme[:secondary]

      primary_name =
        if AdminSuite::ThemePalette.hex?(primary)
          nil
        else
          AdminSuite::ThemePalette.normalize_color(primary, default_name: :indigo)
        end

      secondary_name =
        if AdminSuite::ThemePalette.hex?(secondary)
          nil
        else
          AdminSuite::ThemePalette.normalize_color(secondary, default_name: :purple)
        end

      # Primary variables
      primary_600 = AdminSuite::ThemePalette.hex?(primary) ? primary : AdminSuite::ThemePalette.resolve(primary_name, 600, fallback: "#4f46e5")
      primary_700 = AdminSuite::ThemePalette.hex?(primary) ? primary : AdminSuite::ThemePalette.resolve(primary_name, 700, fallback: "#4338ca")

      # Sidebar gradient variables (dark shades)
      sidebar_from = AdminSuite::ThemePalette.resolve(primary_name || "indigo", 900, fallback: "#312e81")
      sidebar_via = AdminSuite::ThemePalette.resolve(primary_name || "indigo", 800, fallback: "#3730a3")
      sidebar_to =
        if AdminSuite::ThemePalette.hex?(secondary)
          secondary
        else
          AdminSuite::ThemePalette.resolve(secondary_name || "purple", 900, fallback: "#581c87")
        end

      css = <<~CSS
        body.admin-suite {
          --admin-suite-primary: #{primary_600};
          --admin-suite-primary-hover: #{primary_700};
          --admin-suite-sidebar-from: #{sidebar_from};
          --admin-suite-sidebar-via: #{sidebar_via};
          --admin-suite-sidebar-to: #{sidebar_to};
        }
      CSS

      content_tag(:style, css.html_safe)
    end

    def theme_link_class
      "admin-suite-link"
    end

    def theme_link_hover_text_class
      "admin-suite-link-hover"
    end

    def theme_btn_primary_class
      "admin-suite-btn-primary"
    end

    def theme_btn_primary_small_class
      "admin-suite-btn-primary admin-suite-btn-primary--sm"
    end

    def theme_badge_primary_class
      "admin-suite-badge-primary"
    end

    def theme_focus_ring_class
      "admin-suite-focus-ring"
    end

    def theme_sidebar_gradient_class
      # Deprecated: gradient is now CSS-variable driven (see `admin_suite_theme_style_tag`).
      ""
    end
  end
end
