# frozen_string_literal: true

module AdminHelper
  # Generates a breadcrumb navigation for admin pages
  #
  # @param items [Array<Hash, String>] Array of breadcrumb items
  #   Each item can be a String (label only) or Hash with :label and :path
  # @return [String] HTML for breadcrumbs
  #
  # @example
  #   admin_breadcrumbs([
  #     { label: "Users", path: admin_users_path },
  #     { label: @user.display_name }
  #   ])
  def admin_breadcrumbs(items)
    return "" if items.blank?

    content_tag :div, class: "flex items-center gap-2 text-sm text-slate-500 dark:text-slate-400 mb-2" do
      items.each_with_index.map do |item, index|
        crumb = item.is_a?(Hash) ? item : { label: item }
        is_last = index == items.length - 1

        [
          if crumb[:path].present? && !is_last
            link_to(crumb[:label], crumb[:path], class: "hover:text-amber-600 dark:hover:text-amber-400")
          else
            content_tag(:span, crumb[:label], class: "text-slate-900 dark:text-white")
          end,
          unless is_last
            tag.svg(class: "w-4 h-4", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
              tag.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M9 5l7 7-7 7")
            end
          end
        ].compact.join.html_safe
      end.join.html_safe
    end
  end

  # Generates a status badge with consistent styling
  #
  # @param status [String, Symbol] The status value
  # @param custom_colors [Hash] Optional custom color mapping
  # @return [String] HTML for status badge
  #
  # @example
  #   admin_status_badge("active")
  #   admin_status_badge("pending", { pending: "bg-yellow-100 text-yellow-800" })
  def admin_status_badge(status, custom_colors: {})
    return "" if status.blank?

    default_colors = {
      "active" => "bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400",
      "inactive" => "bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-400",
      "pending" => "bg-amber-100 text-amber-800 dark:bg-amber-900/20 dark:text-amber-400",
      "completed" => "bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400",
      "failed" => "bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400",
      "closed" => "bg-slate-100 text-slate-800 dark:bg-slate-700 dark:text-slate-300",
      "draft" => "bg-amber-100 text-amber-800 dark:bg-amber-900/20 dark:text-amber-400"
    }

    color_class = custom_colors[status.to_s] || default_colors[status.to_s] || default_colors["inactive"]

    content_tag :span, class: "px-2 py-0.5 text-xs font-semibold rounded-full #{color_class}" do
      status.to_s.titleize
    end
  end

  # Generates a stat card for the stats grid
  #
  # @param label [String] The stat label
  # @param value [String, Integer] The stat value
  # @param color [String] Optional color class
  # @return [String] HTML for stat card
  #
  # @example
  #   admin_stat_card("Total Users", 150, "text-slate-900")
  def admin_stat_card(label, value, color: "text-slate-900 dark:text-white")
    content_tag :div, class: "bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 p-4" do
      [
        content_tag(:p, label.to_s.humanize, class: "text-xs font-medium text-slate-500 dark:text-slate-400 uppercase"),
        content_tag(:p, value, class: "mt-1 text-2xl font-bold #{color}")
      ].join.html_safe
    end
  end
end
