# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for application settings admin management
    #
    # Provides toggle-based management for boolean feature flags.
    class SettingResource < Admin::Base::Resource
      model ::Setting
      portal :ops
      section :settings

      index do
        searchable :name
        sortable :name, :updated_at, default: :name
        paginate 50

        stats do
          stat :total, -> { ::Setting.count }
          stat :enabled, -> { ::Setting.where(value: true).count }, color: :green
          stat :disabled, -> { ::Setting.where(value: false).count }, color: :slate
        end

        columns do
          column :name, ->(s) { s.name.humanize }
          column :value, type: :toggle, toggle_field: :value
          column :updated_at, ->(s) { s.updated_at&.strftime("%b %d, %H:%M") }
        end

        filters do
          filter :value, type: :select, label: "Status", options: [
            [ "All", "" ],
            [ "Enabled", "true" ],
            [ "Disabled", "false" ]
          ]
        end
      end

      form do
        section "Setting Configuration" do
          field :name, type: :searchable_select, required: true,
                collection: ::Setting::AVAILABLE_SETTINGS.map { |s| [ s.humanize, s ] },
                placeholder: "Select a setting...",
                help: "Choose from available settings"

          field :value, type: :toggle, label: "Enabled",
                help: "Toggle to enable or disable this feature"
        end
      end

      show do
        sidebar do
          panel :status, title: "Status", fields: [ :value ]
          panel :timestamps, title: "Timestamps", fields: [ :created_at, :updated_at ]
        end

        main do
          panel :setting, title: "Setting", fields: [ :name ]
        end
      end

      actions do
        action :toggle, method: :post, label: "Toggle"
      end
    end
  end
end
