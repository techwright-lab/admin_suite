# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for SkillTag admin management
    #
    # Provides CRUD operations with search, filtering, and merge functionality.
    class SkillTagResource < Admin::Base::Resource
      model SkillTag
      portal :ops
      section :content

      index do
        searchable :name
        sortable :name, :created_at, default: :name
        paginate 50

        stats do
          stat :total, -> { SkillTag.count }
          stat :with_users, -> { SkillTag.joins(:user_skills).distinct.count }, color: :blue
          stat :with_resumes, -> { SkillTag.joins(:resume_skills).distinct.count }, color: :green
        end

        columns do
          column :name
          column :user_skills_count, ->(st) { st.user_skills.count }, header: "User Skills"
          column :resume_skills_count, ->(st) { st.resume_skills.count }, header: "Resume Skills"
        end

        filters do
          filter :sort, type: :select, options: [
            [ "Name (A-Z)", "name" ],
            [ "Recently Added", "recent" ],
            [ "Most Used", "usage" ]
          ]
        end
      end

      form do
        field :name, required: true, placeholder: "Skill tag name"
      end

      show do
        section :details, fields: [ :name, :created_at, :updated_at ]
        section :user_skills, association: :user_skills, limit: 20
        section :resume_skills, association: :resume_skills, limit: 20
      end

      actions do
        action :disable, method: :post, confirm: "Disable this skill tag?"
        action :enable, method: :post
        action :merge, type: :modal
        bulk_action :bulk_merge, label: "Merge Selected"
      end

      exportable :json, :csv
    end
  end
end

