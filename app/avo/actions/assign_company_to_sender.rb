# frozen_string_literal: true

class Avo::Actions::AssignCompanyToSender < Avo::BaseAction
  self.name = "Assign Company"
  self.standalone = false
  self.visible = -> { true }

  def fields
    field :company, as: :belongs_to, searchable: true, required: true
    field :verified, as: :boolean, default: true, help: "Mark as verified"
  end

  def handle(query:, fields:, current_user:, resource:, **args)
    company = fields[:company]
    verified = fields[:verified]

    return error "Please select a company" unless company

    query.each do |sender|
      sender.assign_company!(company, verify: verified)
    end

    succeed "Assigned #{query.count} sender(s) to #{company.name}"
  end
end

