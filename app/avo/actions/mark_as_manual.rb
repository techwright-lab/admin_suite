class Avo::Actions::MarkAsManual < Avo::BaseAction
  self.name = "Mark as Manual"
  self.message = "Mark these attempts as manually resolved?"
  self.confirm_button_label = "Mark as Manual"
  self.cancel_button_label = "Cancel"
  self.no_confirmation = false
  
  def handle(**args)
    query, fields, current_user, resource = args.values_at(:query, :fields, :current_user, :resource)
    
    query.each do |scraping_attempt|
      if scraping_attempt.may_mark_manual?
        scraping_attempt.mark_manual!
      end
    end

    succeed "Marked #{query.count} #{'attempt'.pluralize(query.count)} as manual"
  end
end

