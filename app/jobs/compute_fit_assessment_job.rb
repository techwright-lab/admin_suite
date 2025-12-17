# frozen_string_literal: true

# Background job to compute a FitAssessment for a given (user, fittable).
class ComputeFitAssessmentJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  # @param user_id [Integer]
  # @param fittable_type [String]
  # @param fittable_id [Integer]
  def perform(user_id, fittable_type, fittable_id)
    user = User.find(user_id)
    fittable = fittable_type.constantize.find(fittable_id)

    ComputeFitAssessmentService.new(user: user, fittable: fittable).call
  end
end

