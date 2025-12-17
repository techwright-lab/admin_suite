class Avo::Resources::JobRole < Avo::BaseResource
  self.includes = [ :job_listings, :interview_applications ]

  self.search = {
    query: -> { query.ransack(title_cont: params[:q], legacy_category_cont: params[:q], m: "or").result(distinct: false) }
  }

  def fields
    field :id, as: :id
    field :title, as: :text, required: true, sortable: true
    field :category, as: :belongs_to
    field :legacy_category, as: :text, sortable: true
    field :description, as: :textarea

    # Associations
    field :job_listings, as: :has_many
    field :interview_applications, as: :has_many
    field :users_with_current_role, as: :has_many, name: "Current Users"
    field :users_targeting, as: :has_many, through: :user_target_job_roles, name: "Users Targeting"

    # Timestamps
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end

  def filters
    filter Avo::Filters::JobRoleFilter
  end
end
