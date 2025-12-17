class Avo::Resources::SkillTag < Avo::BaseResource
  self.includes = [ :interview_applications ]

  self.search = {
    query: -> { query.ransack(name_cont: params[:q], legacy_category_cont: params[:q], m: "or").result(distinct: false) }
  }

  def fields
    field :id, as: :id
    field :name, as: :text, required: true, sortable: true
    field :category, as: :belongs_to
    field :legacy_category, as: :text, sortable: true

    # Associations
    field :interview_applications, as: :has_many, through: :application_skill_tags

    # Timestamps
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end

  def filters
    filter Avo::Filters::SkillTagFilter
  end
end
