class Avo::Actions::DuplicatePromptTemplate < Avo::BaseAction
  self.name = "Duplicate Template"
  self.message = "Create a copy of this prompt template?"
  self.confirm_button_label = "Duplicate"
  self.cancel_button_label = "Cancel"
  self.no_confirmation = false
  
  def handle(**args)
    query, fields, current_user, resource = args.values_at(:query, :fields, :current_user, :resource)
    
    duplicated = []
    query.each do |template|
      new_template = template.dup
      new_template.name = "#{template.name} (Copy)"
      new_template.active = false
      new_template.version = template.version + 1
      
      if new_template.save
        duplicated << new_template.name
      end
    end

    succeed "Duplicated #{duplicated.count} #{'template'.pluralize(duplicated.count)}"
  end
end

