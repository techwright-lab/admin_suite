class Avo::Resources::ExtractionPromptTemplate < Avo::BaseResource
  self.title = :name
  self.includes = []

  def fields
    field :id, as: :id
    
    # Status
    field :active, as: :boolean, help: "Only one template can be active at a time"
    field :version, as: :number, default: 1, help: "Version number for tracking changes"
    
    # Basic Info
    field :name, as: :text, required: true, help: "Descriptive name for this prompt template"
    field :description, as: :textarea, help: "What makes this prompt unique or when to use it"
    
    # Prompt Template
    field :prompt_template, as: :textarea, required: true, rows: 15, help: "Use {{url}} and {{html_content}} as placeholders"
    
    # Template Variables
    field :template_variables_list, as: :text, computed: true, readonly: true, only_on: [:show] do
      record.template_variables.join(", ")
    end
    
    # Timestamps
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end

  def filters
    filter ActiveFilter
  end

  def actions
    action Avo::Actions::ActivatePromptTemplate
    action Avo::Actions::DuplicatePromptTemplate
  end
  
  # Active filter
  class ActiveFilter < Avo::Filters::BooleanFilter
    self.name = "Active"
    
    def apply(request, query, value)
      return query unless value
      
      query.where(active: true)
    end
  end
end
