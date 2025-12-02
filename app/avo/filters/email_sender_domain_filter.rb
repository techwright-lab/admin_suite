# frozen_string_literal: true

class Avo::Filters::EmailSenderDomainFilter < Avo::Filters::TextFilter
  self.name = "Domain"
  self.button_label = "Filter by domain"

  def apply(request, query, value)
    return query if value.blank?

    query.by_domain(value)
  end
end

