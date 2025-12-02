class Avo::Resources::User < Avo::BaseResource
  self.includes = [:interview_applications, :preference, :current_job_role, :current_company]
  
  self.search = {
    query: -> { query.ransack(name_cont: params[:q], email_address_cont: params[:q], m: "or").result(distinct: false) }
  }

  def fields
    field :id, as: :id
    
    # Basic Information
    field :email_address, as: :text, required: true, sortable: true, name: "Email"
    field :name, as: :text, sortable: true
    field :bio, as: :textarea
    field :years_of_experience, as: :number
    
    # Current Position
    field :current_job_role, as: :belongs_to, searchable: true, name: "Current Role"
    field :current_company, as: :belongs_to, searchable: true, name: "Current Company"
    
    # Social Links
    field :linkedin_url, as: :text, name: "LinkedIn"
    field :github_url, as: :text, name: "GitHub"
    field :gitlab_url, as: :text, name: "GitLab"
    field :twitter_url, as: :text, name: "Twitter"
    field :portfolio_url, as: :text, name: "Portfolio"
    
    # Target Roles & Companies
    field :target_job_roles, as: :has_many, through: :user_target_job_roles, name: "Target Roles"
    field :target_companies, as: :has_many, through: :user_target_companies, name: "Target Companies"
    
    # Applications & Activity
    field :interview_applications, as: :has_many, name: "Applications"
    field :interview_rounds, as: :has_many, through: :interview_applications, name: "Interview Rounds"
    
    # Preferences & Sessions
    field :preference, as: :has_one, name: "User Preference"
    field :sessions, as: :has_many
    
    # Timestamps
    field :created_at, as: :date_time, readonly: true, name: "Joined"
    field :updated_at, as: :date_time, readonly: true
  end
  
  def filters
    filter Avo::Filters::UserExperienceFilter
    filter Avo::Filters::UserWithApplicationsFilter
  end
  
  # Computed fields for dashboard
  def cards
    card Avo::Cards::UserApplicationsCard
    card Avo::Cards::UserActivityCard
  end
end
