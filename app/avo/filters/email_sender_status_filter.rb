# frozen_string_literal: true

class Avo::Filters::EmailSenderStatusFilter < Avo::Filters::SelectFilter
  self.name = "Status"

  def apply(request, query, value)
    case value
    when "unassigned"
      query.unassigned
    when "assigned"
      query.assigned
    when "auto_detected"
      query.auto_detected
    when "verified"
      query.verified
    when "unverified"
      query.unverified
    else
      query
    end
  end

  def options
    {
      "All" => "",
      "Unassigned" => "unassigned",
      "Assigned" => "assigned",
      "Auto-detected" => "auto_detected",
      "Verified" => "verified",
      "Unverified" => "unverified"
    }
  end
end

