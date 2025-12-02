# frozen_string_literal: true

class Avo::Filters::SyncedEmailStatusFilter < Avo::Filters::SelectFilter
  self.name = "Status"

  def apply(request, query, value)
    case value
    when "pending"
      query.pending
    when "processed"
      query.processed
    when "ignored"
      query.ignored
    when "failed"
      query.failed
    when "matched"
      query.matched
    when "unmatched"
      query.unmatched
    else
      query
    end
  end

  def options
    {
      "All" => "",
      "Pending" => "pending",
      "Processed" => "processed",
      "Ignored" => "ignored",
      "Failed" => "failed",
      "Matched" => "matched",
      "Unmatched" => "unmatched"
    }
  end
end

