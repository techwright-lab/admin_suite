# frozen_string_literal: true

module AdminSuite
  module ThemeHelper
    def admin_suite_theme
      (AdminSuite.config.theme || {}).symbolize_keys
    rescue StandardError
      {}
    end

    def theme_primary
      (admin_suite_theme[:primary] || :indigo).to_s
    end

    def theme_secondary
      (admin_suite_theme[:secondary] || :purple).to_s
    end

    def theme_link_class
      # Keep links readable and consistent with the old developer portal:
      # no underline; use a subtle hover background instead.
      "inline-flex items-center px-2 py-1 rounded-md text-#{theme_primary}-700 hover:text-#{theme_primary}-800 hover:bg-#{theme_primary}-50 transition-colors"
    end

    def theme_link_hover_text_class
      "hover:text-#{theme_primary}-700 transition-colors"
    end

    def theme_btn_primary_class
      # Include a stable engine-owned class so buttons remain readable even if the
      # host app doesn't ship Tailwind (or Tailwind utilities are missing).
      "admin-suite-btn-primary inline-flex items-center gap-2 px-4 py-2 bg-#{theme_primary}-600 hover:bg-#{theme_primary}-700 text-white text-sm font-medium rounded-lg transition-colors"
    end

    def theme_btn_primary_small_class
      "px-6 py-2 bg-#{theme_primary}-600 hover:bg-#{theme_primary}-700 text-white text-sm font-medium rounded-lg transition-colors"
    end

    def theme_badge_primary_class
      "bg-#{theme_primary}-100 text-#{theme_primary}-700"
    end

    def theme_focus_ring_class
      "focus:ring-2 focus:ring-#{theme_primary}-500"
    end

    def theme_sidebar_gradient_class
      "from-#{theme_primary}-900 via-#{theme_primary}-800 to-#{theme_secondary}-900"
    end
  end
end
