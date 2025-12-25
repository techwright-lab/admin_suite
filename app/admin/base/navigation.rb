# frozen_string_literal: true

module Admin
  module Base
    # Navigation builder for admin portals
    #
    # Builds navigation structure from portal and resource definitions.
    # Used by the sidebar partial to render navigation links.
    #
    # @example
    #   navigation = Admin::Base::Navigation.new(current_portal, current_path)
    #   navigation.sections.each do |section|
    #     section.items.each do |item|
    #       # render nav item
    #     end
    #   end
    class Navigation
      attr_reader :portal, :current_path

      NavSection = Struct.new(:key, :label, :icon, :items, keyword_init: true)
      NavItem = Struct.new(:key, :label, :path, :icon, :badge, :active, keyword_init: true)

      # Icon mappings for resources
      RESOURCE_ICONS = {
        dashboard: :home,
        users: :users,
        email_senders: :mail,
        connected_accounts: :link,
        synced_emails: :inbox,
        blog_posts: :document_text,
        companies: :building_office,
        job_roles: :briefcase,
        job_listings: :clipboard_list,
        categories: :tag,
        skill_tags: :hashtag,
        scraping_metrics: :chart_bar,
        scraping_attempts: :clock,
        scraping_events: :bell,
        html_scraping_logs: :code,
        support_tickets: :ticket,
        interview_applications: :document,
        settings: :cog,
        assistant_threads: :chat_bubble_left_right,
        assistant_turns: :arrow_path,
        assistant_events: :bolt,
        assistant_tools: :wrench,
        assistant_tool_executions: :play,
        assistant_user_memories: :light_bulb,
        assistant_memory_proposals: :clipboard_check,
        assistant_thread_summaries: :document_text,
        llm_prompts: :command_line,
        llm_provider_configs: :cpu_chip,
        llm_api_logs: :server
      }.freeze

      def initialize(portal, current_path)
        @portal = portal
        @current_path = current_path
      end

      # Returns navigation sections for the portal
      #
      # @return [Array<NavSection>]
      def sections
        return [] unless portal&.sections_list

        portal.sections_list.map do |section|
          NavSection.new(
            key: section.key,
            label: section.display_label,
            icon: section.section_icon,
            items: items_for_section(section)
          )
        end
      end

      # Returns the portal switcher data
      #
      # @return [Array<Hash>]
      def portal_switcher
        Portal.registered_portals.map do |p|
          {
            key: p.identifier,
            name: p.portal_name,
            icon: p.portal_icon,
            path: p.portal_path_prefix,
            active: portal == p
          }
        end
      end

      private

      def items_for_section(section)
        section.resource_keys.map do |key|
          build_nav_item(key)
        end.compact
      end

      def build_nav_item(key)
        path = path_for_resource(key)
        return nil unless path

        NavItem.new(
          key: key,
          label: label_for_resource(key),
          path: path,
          icon: RESOURCE_ICONS[key] || :folder,
          badge: badge_for_resource(key),
          active: current_path&.start_with?(path)
        )
      end

      def path_for_resource(key)
        case portal.identifier
        when :operations
          ops_path_for(key)
        when :ai
          ai_path_for(key)
        else
          "/admin/#{key}"
        end
      end

      def ops_path_for(key)
        case key
        when :dashboard then "/admin"
        when :scraping_metrics then "/admin/scraping_metrics"
        else "/admin/#{key}"
        end
      end

      def ai_path_for(key)
        case key
        when :dashboard then "/admin/ai"
        when :llm_prompts then "/admin/ai/llm_prompts"
        when :llm_api_logs then "/admin/ai/llm_api_logs"
        else "/admin/#{key}"
        end
      end

      def label_for_resource(key)
        key.to_s.humanize.titleize
      end

      def badge_for_resource(key)
        case key
        when :email_senders
          count = EmailSender.unassigned.count rescue 0
          count.positive? ? count : nil
        when :support_tickets
          count = SupportTicket.open_tickets.count rescue 0
          count.positive? ? count : nil
        when :synced_emails
          count = SyncedEmail.needs_review.count rescue 0
          count.positive? ? count : nil
        else
          nil
        end
      end
    end
  end
end

