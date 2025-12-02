class Avo::Resources::Setting < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :description, as: :textarea
    field :name, as: :text
    field :value, as: :boolean
  end
end
