# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Assistant User Memory admin management
    #
    # Provides read-only access to user memories with delete capability.
    class AssistantUserMemoryResource < Admin::Base::Resource
      model ::Assistant::Memory::UserMemory
      portal :assistant
      section :memory

      index do
        searchable :key
        sortable :created_at, :expires_at, default: :created_at
        paginate 30

        stats do
          stat :total, -> { ::Assistant::Memory::UserMemory.count }
          stat :active, -> { ::Assistant::Memory::UserMemory.active.count }, color: :green
          stat :expired, -> { ::Assistant::Memory::UserMemory.where("expires_at IS NOT NULL AND expires_at <= ?", Time.current).count }, color: :red
          stat :user_source, -> { ::Assistant::Memory::UserMemory.where(source: "user").count }, color: :blue
          stat :assistant_source, -> { ::Assistant::Memory::UserMemory.where(source: "assistant").count }, color: :amber
        end

        columns do
          column :user, ->(um) { um.user&.email_address }
          column :key, ->(um) { um.key&.truncate(40) }
          column :source
          column :active, ->(um) { (um.expires_at.nil? || um.expires_at > Time.current) ? "Yes" : "No" }
          column :expires_at, ->(um) { um.expires_at&.strftime("%b %d, %Y") || "Never" }
          column :created_at, ->(um) { um.created_at.strftime("%b %d, %H:%M") }
        end

        filters do
          filter :source, type: :select, options: [
            ["All Sources", ""],
            ["User", "user"],
            ["Assistant", "assistant"]
          ]
          filter :active, type: :select, options: [
            ["All", ""],
            ["Active", "true"],
            ["Expired", "false"]
          ]
          filter :user_id, type: :number, label: "User ID"
        end
      end

      show do
        sidebar do
          panel :meta, title: "Metadata", fields: [:source, :expires_at]
          panel :timestamps, title: "Timestamps", fields: [:created_at, :updated_at]
        end
        
        main do
          panel :user, title: "User", fields: [:user]
          panel :memory, title: "Memory Content", fields: [:key, :value]
        end
      end

      actions do
        action :delete, method: :delete, label: "Delete", 
               confirm: "Delete this memory? This cannot be undone.",
               color: :danger
      end

      exportable :json
    end
  end
end

