# frozen_string_literal: true

class Avo::Filters::SyncedEmailTypeFilter < Avo::Filters::SelectFilter
  self.name = "Email Type"

  def apply(request, query, value)
    return query if value.blank?

    query.by_type(value)
  end

  def options
    options = { "All" => "" }
    SyncedEmail::EMAIL_TYPES.each do |type|
      options[type.titleize] = type
    end
    options
  end
end

