# frozen_string_literal: true

class Avo::Resources::EmailSender < Avo::BaseResource
  self.includes = [:company, :auto_detected_company, :synced_emails]
  
  self.search = {
    query: -> { query.ransack(email_cont: params[:q], name_cont: params[:q], domain_cont: params[:q], m: "or").result(distinct: false) }
  }

  def fields
    field :id, as: :id
    field :email, as: :text, required: true, sortable: true, link_to_resource: true
    field :name, as: :text, sortable: true
    field :domain, as: :text, sortable: true
    field :sender_type, as: :select, options: EmailSender::SENDER_TYPES.map { |t| [t.titleize, t] }.to_h
    
    # Company associations
    field :company, as: :belongs_to, searchable: true, help: "Manually assigned company"
    field :auto_detected_company, as: :belongs_to, searchable: true, help: "Auto-detected company", readonly: true
    
    # Stats
    field :email_count, as: :number, sortable: true, readonly: true
    field :last_seen_at, as: :date_time, sortable: true, readonly: true
    field :verified, as: :boolean, help: "Admin verified the company association"
    
    # Related emails
    field :synced_emails, as: :has_many
    
    # Timestamps
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end
  
  def filters
    filter Avo::Filters::EmailSenderStatusFilter
    filter Avo::Filters::EmailSenderDomainFilter
  end
  
  def actions
    action Avo::Actions::AssignCompanyToSender
    action Avo::Actions::BulkAssignDomainToCompany
  end
end

