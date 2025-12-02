# frozen_string_literal: true

class Avo::Resources::SyncedEmail < Avo::BaseResource
  self.includes = [:user, :interview_application, :email_sender]
  
  self.search = {
    query: -> { query.ransack(subject_cont: params[:q], from_email_cont: params[:q], m: "or").result(distinct: false) }
  }

  def fields
    field :id, as: :id
    field :subject, as: :text, sortable: true, link_to_resource: true
    field :from_email, as: :text, sortable: true
    field :from_name, as: :text
    field :email_date, as: :date_time, sortable: true
    field :email_type, as: :select, options: SyncedEmail::EMAIL_TYPES.map { |t| [t.titleize, t] }.to_h
    field :status, as: :badge, map: {
      pending: :warning,
      processed: :success,
      ignored: :neutral,
      failed: :danger
    }
    field :detected_company, as: :text, readonly: true
    
    # Associations
    field :user, as: :belongs_to, readonly: true
    field :interview_application, as: :belongs_to, searchable: true
    field :email_sender, as: :belongs_to
    
    # Content (hidden on index for performance)
    field :snippet, as: :textarea, hide_on: :index
    field :body_preview, as: :textarea, hide_on: :index
    
    # Metadata
    field :gmail_id, as: :text, readonly: true, hide_on: :index
    field :thread_id, as: :text, readonly: true, hide_on: :index
    
    # Timestamps
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end
  
  def filters
    filter Avo::Filters::SyncedEmailStatusFilter
    filter Avo::Filters::SyncedEmailTypeFilter
  end
end

