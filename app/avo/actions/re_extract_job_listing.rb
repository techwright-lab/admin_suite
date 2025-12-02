class Avo::Actions::ReExtractJobListing < Avo::BaseAction
  self.name = "Re-extract Data"
  self.message = "Queue extraction for the selected job listings?"
  self.confirm_button_label = "Re-extract"
  self.cancel_button_label = "Cancel"
  self.no_confirmation = false

  def handle(**args)
    query, fields, current_user, resource = args.values_at(:query, :fields, :current_user, :resource)
    
    count = 0
    query.each do |job_listing|
      if job_listing.url.present?
        ScrapeJobListingJob.perform_later(job_listing)
        count += 1
      end
    end

    succeed "Queued extraction for #{count} job #{'listing'.pluralize(count)}"
  end
end

