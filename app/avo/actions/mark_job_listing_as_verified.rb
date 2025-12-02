class Avo::Actions::MarkJobListingAsVerified < Avo::BaseAction
  self.name = "Mark as Verified"
  self.message = "Mark these job listings as admin-verified?"
  self.confirm_button_label = "Mark as Verified"
  self.cancel_button_label = "Cancel"
  self.no_confirmation = false

  def handle(**args)
    query, fields, current_user, resource = args.values_at(:query, :fields, :current_user, :resource)
    
    query.each do |job_listing|
      scraped_data = job_listing.scraped_data || {}
      scraped_data["verified_by_admin"] = true
      scraped_data["verified_at"] = Time.current.iso8601
      scraped_data["verified_by"] = current_user&.email || "admin"
      
      job_listing.update(scraped_data: scraped_data)
    end

    succeed "Marked #{query.count} job #{'listing'.pluralize(query.count)} as verified"
  end
end

