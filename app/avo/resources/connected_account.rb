class Avo::Resources::ConnectedAccount < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :user, as: :belongs_to
    field :provider, as: :text
    field :uid, as: :text
    field :access_token, as: :textarea
    field :refresh_token, as: :textarea
    field :expires_at, as: :date_time
    field :scopes, as: :text
    field :email, as: :text
    field :last_synced_at, as: :date_time
    field :sync_enabled, as: :boolean
  end
end
