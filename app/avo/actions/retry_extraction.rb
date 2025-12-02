class Avo::Actions::RetryExtraction < Avo::BaseAction
  self.name = "Retry Extraction"
  self.message = "Are you sure you want to retry extraction for the selected attempts?"
  self.confirm_button_label = "Retry"
  self.cancel_button_label = "Cancel"
  self.no_confirmation = false

  def handle(**args)
    query, fields, current_user, resource = args.values_at(:query, :fields, :current_user, :resource)
    
    query.each do |scraping_attempt|
      # Reset the attempt and queue a new job
      job_listing = scraping_attempt.job_listing
      
      if job_listing
        scraping_attempt.update(
          status: :pending,
          error_message: nil,
          retry_count: scraping_attempt.retry_count + 1
        )
        
        ScrapeJobListingJob.perform_later(job_listing)
      end
    end

    succeed "Extraction retry queued for #{query.count} #{'attempt'.pluralize(query.count)}"
  end
end

