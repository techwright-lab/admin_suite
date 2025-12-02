class Avo::Actions::ActivatePromptTemplate < Avo::BaseAction
  self.name = "Activate Template"
  self.message = "Activate this prompt template? (Will deactivate all others)"
  self.confirm_button_label = "Activate"
  self.cancel_button_label = "Cancel"
  self.no_confirmation = false
  
  def handle(**args)
    query, fields, current_user, resource = args.values_at(:query, :fields, :current_user, :resource)
    
    # Only activate one template
    template = query.first
    
    if template
      # Deactivate all others
      ExtractionPromptTemplate.where.not(id: template.id).update_all(active: false)
      
      # Activate this one
      template.update(active: true)
      
      succeed "Activated template: #{template.name}"
    else
      error "No template selected"
    end
  end
end

