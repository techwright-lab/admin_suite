class Avo::Resources::CompanyFeedback < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :application, as: :belongs_to
    field :feedback_text, as: :textarea
    field :received_at, as: :date_time
    field :rejection_reason, as: :textarea
    field :next_steps, as: :textarea
    field :self_reflection, as: :textarea
  end
end
