# frozen_string_literal: true

module Internal
  module Developer
    # Helper methods for dashboard cards and health metrics
    module DashboardHelper
      # Renders a stat card
      #
      # @param label [String] The label text
      # @param value [String, Integer] The value to display
      # @param options [Hash] Additional options
      # @option options [Symbol] :color Color theme (:default, :green, :red, :amber, :cyan, :violet)
      # @option options [String] :subtitle Additional text below the value
      # @option options [String] :trend Trend indicator (e.g., "+5%", "-2%")
      # @option options [Symbol] :trend_direction :up, :down, or :neutral
      # @return [String] HTML for the stat card
      def stat_card(label, value, **options)
        color = options[:color] || :default
        color_classes = stat_color_classes(color)

        content_tag(:div, class: "#{color_classes[:bg]} rounded-xl p-5 #{color_classes[:border]}") do
          concat(content_tag(:div, class: "flex items-center justify-between") do
            concat(content_tag(:div, value.to_s, class: "text-3xl font-bold #{color_classes[:text]}"))
            if options[:trend].present?
              trend_class = case options[:trend_direction]
                            when :up then "text-green-500"
                            when :down then "text-red-500"
                            else "text-slate-400"
                            end
              concat(content_tag(:span, options[:trend], class: "text-sm font-medium #{trend_class}"))
            end
          end)
          concat(content_tag(:div, label, class: "text-sm #{color_classes[:label]} mt-1"))
          if options[:subtitle].present?
            concat(content_tag(:div, options[:subtitle], class: "text-xs #{color_classes[:label]} mt-1 opacity-75"))
          end
        end
      end

      # Renders a health status card
      #
      # @param title [String] The system name
      # @param status [Symbol] :healthy, :degraded, :critical, or :unknown
      # @param metrics [Hash] Key-value pairs of metrics to display
      # @return [String] HTML for the health card
      def health_card(title, status, metrics: {})
        status_config = health_status_config(status)

        content_tag(:div, class: "bg-white dark:bg-slate-800 rounded-xl border #{status_config[:border]} overflow-hidden") do
          # Header
          concat(content_tag(:div, class: "px-4 py-3 border-b border-slate-200 dark:border-slate-700 flex items-center justify-between") do
            concat(content_tag(:h3, title, class: "font-semibold text-slate-900 dark:text-white"))
            concat(content_tag(:span, class: "flex items-center gap-1.5 px-2 py-1 rounded-full text-xs font-medium #{status_config[:badge]}") do
              concat(content_tag(:span, "", class: "w-2 h-2 rounded-full #{status_config[:dot]}"))
              concat(status.to_s.humanize)
            end)
          end)

          # Metrics
          if metrics.any?
            concat(content_tag(:div, class: "p-4 grid grid-cols-2 gap-3") do
              metrics.each do |key, val|
                concat(content_tag(:div) do
                  concat(content_tag(:div, val.to_s, class: "text-lg font-semibold text-slate-900 dark:text-white"))
                  concat(content_tag(:div, key.to_s.humanize, class: "text-xs text-slate-500 dark:text-slate-400"))
                end)
              end
            end)
          end
        end
      end

      # Renders a recent items list card
      #
      # @param title [String] Card title
      # @param items [Array] Array of records to display
      # @param options [Hash] Display options
      # @option options [String] :path_helper Helper method name for item links
      # @option options [Symbol] :title_field Field to use for item title
      # @option options [Symbol] :subtitle_field Field to use for subtitle
      # @option options [Symbol] :badge_field Field to use for status badge
      # @option options [String] :empty_message Message when no items
      # @option options [String] :view_all_path Link to view all items
      # @return [String] HTML for the recent items card
      def recent_items_card(title, items, **options)
        content_tag(:div, class: "bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden") do
          # Header
          concat(content_tag(:div, class: "px-4 py-3 border-b border-slate-200 dark:border-slate-700 flex items-center justify-between") do
            concat(content_tag(:h3, title, class: "font-semibold text-slate-900 dark:text-white"))
            if options[:view_all_path].present?
              concat(link_to("View all →", options[:view_all_path], 
                     class: "text-sm text-indigo-600 dark:text-indigo-400 hover:underline"))
            end
          end)

          # Items list
          if items.any?
            concat(content_tag(:ul, class: "divide-y divide-slate-100 dark:divide-slate-700") do
              items.each do |item|
                concat(render_recent_item(item, options))
              end
            end)
          else
            concat(content_tag(:div, class: "p-4 text-center text-sm text-slate-500 dark:text-slate-400") do
              options[:empty_message] || "No recent items"
            end)
          end
        end
      end

      # Renders a mini chart card (sparkline-style)
      #
      # @param title [String] Card title
      # @param data [Array<Hash>] Array of { label:, value: } hashes
      # @param options [Hash] Display options
      # @option options [Symbol] :color Color theme
      # @option options [String] :total Total value to display
      # @return [String] HTML for the chart card
      def chart_card(title, data, **options)
        max_value = data.map { |d| d[:value].to_f }.max || 1
        max_value = 1 if max_value.zero? # Avoid division by zero
        bar_color = chart_bar_color(options[:color])

        content_tag(:div, class: "bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-4") do
          # Header
          concat(content_tag(:div, class: "flex items-center justify-between mb-4") do
            concat(content_tag(:h3, title, class: "font-semibold text-slate-900 dark:text-white"))
            if options[:total].present?
              concat(content_tag(:span, options[:total], class: "text-2xl font-bold text-slate-900 dark:text-white"))
            end
          end)

          # Bar chart
          concat(content_tag(:div, class: "flex items-end gap-1 h-16") do
            data.each do |d|
              value = d[:value].to_f
              height_float = max_value > 0 ? ((value / max_value) * 100) : 0.0
              # Check for NaN or infinite before rounding
              height_float = 0.0 if height_float.nan? || height_float.infinite?
              height = height_float.round
              concat(content_tag(:div, class: "flex-1 flex flex-col items-center gap-1") do
                concat(content_tag(:div, "", 
                       class: "w-full rounded-t #{bar_color} transition-all",
                       style: "height: #{height}%",
                       title: "#{d[:label]}: #{d[:value]}"))
              end)
            end
          end)

          # Labels
          concat(content_tag(:div, class: "flex gap-1 mt-2") do
            data.each do |d|
              concat(content_tag(:div, d[:label].to_s.first(3), 
                     class: "flex-1 text-center text-xs text-slate-400 dark:text-slate-500"))
            end
          end)
        end
      end

      # Renders an activity timeline card
      #
      # @param title [String] Card title
      # @param activities [Array<Hash>] Array of { title:, time:, icon:, color: }
      # @return [String] HTML for the activity card
      def activity_card(title, activities)
        content_tag(:div, class: "bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden") do
          concat(content_tag(:div, class: "px-4 py-3 border-b border-slate-200 dark:border-slate-700") do
            content_tag(:h3, title, class: "font-semibold text-slate-900 dark:text-white")
          end)

          if activities.any?
            concat(content_tag(:div, class: "p-4 space-y-4") do
              activities.each do |activity|
                concat(render_activity_item(activity))
              end
            end)
          else
            concat(content_tag(:div, class: "p-4 text-center text-sm text-slate-500 dark:text-slate-400") do
              "No recent activity"
            end)
          end
        end
      end

      private

      def stat_color_classes(color)
        case color
        when :green
          {
            bg: "bg-gradient-to-br from-green-50 to-green-100 dark:from-green-900/20 dark:to-green-800/20",
            border: "border border-green-200 dark:border-green-800/50",
            text: "text-green-700 dark:text-green-400",
            label: "text-green-600 dark:text-green-500"
          }
        when :red
          {
            bg: "bg-gradient-to-br from-red-50 to-red-100 dark:from-red-900/20 dark:to-red-800/20",
            border: "border border-red-200 dark:border-red-800/50",
            text: "text-red-700 dark:text-red-400",
            label: "text-red-600 dark:text-red-500"
          }
        when :amber
          {
            bg: "bg-gradient-to-br from-amber-50 to-amber-100 dark:from-amber-900/20 dark:to-amber-800/20",
            border: "border border-amber-200 dark:border-amber-800/50",
            text: "text-amber-700 dark:text-amber-400",
            label: "text-amber-600 dark:text-amber-500"
          }
        when :cyan
          {
            bg: "bg-gradient-to-br from-cyan-50 to-cyan-100 dark:from-cyan-900/20 dark:to-cyan-800/20",
            border: "border border-cyan-200 dark:border-cyan-800/50",
            text: "text-cyan-700 dark:text-cyan-400",
            label: "text-cyan-600 dark:text-cyan-500"
          }
        when :violet
          {
            bg: "bg-gradient-to-br from-violet-50 to-violet-100 dark:from-violet-900/20 dark:to-violet-800/20",
            border: "border border-violet-200 dark:border-violet-800/50",
            text: "text-violet-700 dark:text-violet-400",
            label: "text-violet-600 dark:text-violet-500"
          }
        else
          {
            bg: "bg-white dark:bg-slate-800",
            border: "border border-slate-200 dark:border-slate-700",
            text: "text-slate-900 dark:text-white",
            label: "text-slate-500 dark:text-slate-400"
          }
        end
      end

      def health_status_config(status)
        case status
        when :healthy
          {
            border: "border-green-200 dark:border-green-800/50",
            badge: "bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400",
            dot: "bg-green-500 animate-pulse"
          }
        when :degraded
          {
            border: "border-amber-200 dark:border-amber-800/50",
            badge: "bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400",
            dot: "bg-amber-500 animate-pulse"
          }
        when :critical
          {
            border: "border-red-200 dark:border-red-800/50",
            badge: "bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400",
            dot: "bg-red-500 animate-pulse"
          }
        else
          {
            border: "border-slate-200 dark:border-slate-700",
            badge: "bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400",
            dot: "bg-slate-400"
          }
        end
      end

      def render_recent_item(item, options)
        title_value = item.public_send(options[:title_field] || :id)
        # Handle ActiveRecord associations - try to get a display name
        title = if title_value.respond_to?(:name)
                  title_value.name
                elsif title_value.respond_to?(:title)
                  title_value.title
                elsif title_value.respond_to?(:email_address)
                  title_value.email_address
                else
                  title_value.to_s
                end
        
        subtitle_value = options[:subtitle_field] ? item.public_send(options[:subtitle_field]) : nil
        subtitle = if subtitle_value.respond_to?(:name)
                     subtitle_value.name
                   elsif subtitle_value.respond_to?(:title)
                     subtitle_value.title
                   elsif subtitle_value.respond_to?(:email_address)
                     subtitle_value.email_address
                   else
                     subtitle_value&.to_s
                   end
        
        badge = options[:badge_field] ? item.public_send(options[:badge_field]) : nil
        path = if options[:path_helper]
                 if options[:path_helper].respond_to?(:call)
                   options[:path_helper].call(item)
                 else
                   send(options[:path_helper], item)
                 end
               else
                 nil
               end

        content_tag(:li, class: "px-4 py-3 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors") do
          wrapper = path ? link_to(path, class: "block") : content_tag(:div)
          
          if path
            link_to(path, class: "flex items-center justify-between") do
              concat(render_recent_item_content(title, subtitle, item))
              if badge
                concat(content_tag(:span, badge.to_s.humanize, 
                       class: "px-2 py-1 text-xs rounded-full bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400"))
              end
            end
          else
            content_tag(:div, class: "flex items-center justify-between") do
              concat(render_recent_item_content(title, subtitle, item))
              if badge
                concat(content_tag(:span, badge.to_s.humanize, 
                       class: "px-2 py-1 text-xs rounded-full bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400"))
              end
            end
          end
        end
      end

      def render_recent_item_content(title, subtitle, item)
        content_tag(:div) do
          concat(content_tag(:div, title.to_s.truncate(40), class: "text-sm font-medium text-slate-900 dark:text-white"))
          if subtitle.present?
            concat(content_tag(:div, subtitle.to_s, class: "text-xs text-slate-500 dark:text-slate-400"))
          elsif item.respond_to?(:created_at)
            concat(content_tag(:div, time_ago_in_words(item.created_at) + " ago", 
                   class: "text-xs text-slate-500 dark:text-slate-400"))
          end
        end
      end

      def render_activity_item(activity)
        icon_classes = activity_icon_classes(activity[:color])
        
        content_tag(:div, class: "flex gap-3") do
          concat(content_tag(:div, class: "flex-shrink-0 w-8 h-8 rounded-full #{icon_classes[:bg]} flex items-center justify-center") do
            content_tag(:span, activity[:icon] || "•", class: icon_classes[:text])
          end)
          concat(content_tag(:div, class: "flex-1 min-w-0") do
            concat(content_tag(:p, activity[:title], class: "text-sm text-slate-900 dark:text-white"))
            concat(content_tag(:p, activity[:time], class: "text-xs text-slate-500 dark:text-slate-400"))
          end)
        end
      end

      def chart_bar_color(color)
        case color
        when :amber then "bg-amber-500 dark:bg-amber-400"
        when :green then "bg-green-500 dark:bg-green-400"
        when :red then "bg-red-500 dark:bg-red-400"
        when :cyan then "bg-cyan-500 dark:bg-cyan-400"
        when :violet then "bg-violet-500 dark:bg-violet-400"
        when :indigo then "bg-indigo-500 dark:bg-indigo-400"
        else "bg-indigo-500 dark:bg-indigo-400"
        end
      end

      def activity_icon_classes(color)
        case color
        when :green
          { bg: "bg-green-100 dark:bg-green-900/30", text: "text-green-600 dark:text-green-400" }
        when :red
          { bg: "bg-red-100 dark:bg-red-900/30", text: "text-red-600 dark:text-red-400" }
        when :amber
          { bg: "bg-amber-100 dark:bg-amber-900/30", text: "text-amber-600 dark:text-amber-400" }
        when :cyan
          { bg: "bg-cyan-100 dark:bg-cyan-900/30", text: "text-cyan-600 dark:text-cyan-400" }
        when :violet
          { bg: "bg-violet-100 dark:bg-violet-900/30", text: "text-violet-600 dark:text-violet-400" }
        else
          { bg: "bg-slate-100 dark:bg-slate-700", text: "text-slate-600 dark:text-slate-400" }
        end
      end
    end
  end
end

