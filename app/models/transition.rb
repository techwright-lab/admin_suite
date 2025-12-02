class Transition < ApplicationRecord
  belongs_to :resource, polymorphic: true
end
