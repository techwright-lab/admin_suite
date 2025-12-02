module Transitionable
  extend ActiveSupport::Concern

  included do
    include AASM

    has_many :transitions, as: :resource, dependent: :destroy
  end

  def transitioned?(status)
    transitions.pluck(:from_state).include? status
  end

  def transitioned_at(status)
    transitions.where(from_state: status.to_s.downcase).last&.created_at
  end
end
