class Avo::Resources::Company < Avo::BaseResource
  self.includes = [ :job_listings, :interview_applications ]

  self.search = {
    query: -> { query.ransack(name_cont: params[:q], website_cont: params[:q], m: "or").result(distinct: false) }
  }

  def fields
    field :id, as: :id
    field :name, as: :text, required: true, sortable: true
    field :website, as: :text, sortable: true
    field :about, as: :textarea
    field :logo_url, as: :text, help: "URL to company logo"

    # Associations
    field :job_listings, as: :has_many
    field :interview_applications, as: :has_many
    field :users_with_current_company, as: :has_many, name: "Current Employees"
    field :users_targeting, as: :has_many, through: :user_target_companies, name: "Users Targeting"

    # Timestamps
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end

  def filters
    # filter Avo::Filters::CompanyFilter
  end
end
