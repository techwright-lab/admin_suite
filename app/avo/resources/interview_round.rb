class Avo::Resources::InterviewRound < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :application, as: :belongs_to
    field :stage, as: :select
    field :stage_name, as: :text
    field :scheduled_at, as: :date_time
    field :completed_at, as: :date_time
    field :duration_minutes, as: :number
    field :interviewer_name, as: :text
    field :interviewer_role, as: :text
    field :notes, as: :textarea
    field :result, as: :number
    field :position, as: :number
  end
end
