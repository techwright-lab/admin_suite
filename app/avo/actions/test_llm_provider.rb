class Avo::Actions::TestLlmProvider < Avo::BaseAction
  self.name = "Test Provider"
  self.message = "Test extraction with a sample job listing?"
  self.confirm_button_label = "Test"
  self.cancel_button_label = "Cancel"
  self.no_confirmation = false
  
  def handle(**args)
    query, fields, current_user, resource = args.values_at(:query, :fields, :current_user, :resource)
    
    results = []
    query.each do |provider_config|
      unless provider_config.ready?
        results << "#{provider_config.name}: Not ready (missing API key or disabled)"
        next
      end
      
      # TODO: Implement actual test with sample HTML
      results << "#{provider_config.name}: Test not yet implemented"
    end

    succeed results.join("\n")
  end
end

