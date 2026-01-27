# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Assistant Memory Proposal admin management
    #
    # Provides read-only access to memory proposals for debugging.
    class AssistantMemoryProposalResource < Admin::Base::Resource
      model ::Assistant::Memory::MemoryProposal
      portal :assistant
      section :memory

      index do
        sortable :created_at, default: :created_at
        paginate 30

        stats do
          stat :total, -> { ::Assistant::Memory::MemoryProposal.count }
          stat :pending, -> { ::Assistant::Memory::MemoryProposal.where(status: "pending").count }, color: :amber
          stat :accepted, -> { ::Assistant::Memory::MemoryProposal.where(status: "accepted").count }, color: :green
          stat :rejected, -> { ::Assistant::Memory::MemoryProposal.where(status: "rejected").count }, color: :red
          stat :last_24h, -> { ::Assistant::Memory::MemoryProposal.where("created_at >= ?", 24.hours.ago).count }, color: :blue
        end

        columns do
          column :user, ->(mp) { mp.user&.email_address }
          column :status, type: :label, label_color: ->(mp) {
            case mp.status.to_sym
            when :pending then :amber
            when :accepted then :green
            when :rejected then :red
            else :gray
            end
          }
          column :items_count, ->(mp) { mp.proposed_items&.size || 0 }, header: "Items"
          column :thread, ->(mp) { mp.thread&.display_title&.truncate(25) }
          column :created_at, ->(mp) { mp.created_at.strftime("%b %d, %H:%M") }
        end

        filters do
          filter :status, type: :select, options: [
            [ "All Statuses", "" ],
            [ "Pending", "pending" ],
            [ "Accepted", "accepted" ],
            [ "Rejected", "rejected" ]
          ]
          filter :user_id, type: :number, label: "User ID"
          filter :thread_id, type: :number, label: "Thread ID"
          filter :trace_id, type: :text, placeholder: "Trace ID..."
        end
      end

      show do
        sidebar do
          panel :status, title: "Status", fields: [ :status, :confirmed_by, :confirmed_at ]
          panel :ids, title: "Identifiers", fields: [ :trace_id ]
          panel :timestamps, title: "Timestamps", fields: [ :created_at, :updated_at ]
        end

        main do
          panel :user, title: "User", fields: [ :user ]
          panel :thread, title: "Thread", fields: [ :thread ]
          panel :proposal, title: "Proposed Items", fields: [ :proposed_items ]
        end
      end

      exportable :json
    end
  end
end
