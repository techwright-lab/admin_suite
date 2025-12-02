# frozen_string_literal: true

class Avo::Actions::BulkAssignDomainToCompany < Avo::BaseAction
  self.name = "Assign Domain to Company"
  self.standalone = true
  self.visible = -> { true }

  def fields
    field :domain, as: :text, required: true, help: "Email domain (e.g., company.com)"
    field :company, as: :belongs_to, searchable: true, required: true
    field :verified, as: :boolean, default: true, help: "Mark all as verified"
  end

  def handle(query:, fields:, current_user:, resource:, **args)
    domain = fields[:domain]&.strip&.downcase
    company = fields[:company]
    verified = fields[:verified]

    return error "Please enter a domain" if domain.blank?
    return error "Please select a company" unless company

    matcher = Gmail::CompanyMatcherService.new
    count = matcher.assign_domain_to_company(domain, company, verify: verified)

    if count > 0
      succeed "Assigned #{count} sender(s) from #{domain} to #{company.name}"
    else
      warn "No senders found for domain #{domain}"
    end
  end
end

