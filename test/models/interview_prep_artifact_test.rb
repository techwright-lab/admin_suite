# frozen_string_literal: true

require "test_helper"

class InterviewPrepArtifactTest < ActiveSupport::TestCase
  test "is valid with required fields" do
    artifact = build(:interview_prep_artifact)
    assert artifact.valid?
  end

  test "requires inputs_digest" do
    artifact = build(:interview_prep_artifact, inputs_digest: nil)
    assert_not artifact.valid?
    assert_includes artifact.errors[:inputs_digest], "can't be blank"
  end

  test "requires user to match application owner" do
    application = create(:interview_application)
    other_user = create(:user)

    artifact = build(:interview_prep_artifact, interview_application: application, user: other_user)
    assert_not artifact.valid?
    assert_includes artifact.errors[:user], "must match the interview application's owner"
  end

  test "enforces unique kind per application" do
    application = create(:interview_application)
    create(:interview_prep_artifact, interview_application: application, user: application.user, kind: :match_analysis)

    dup = build(:interview_prep_artifact, interview_application: application, user: application.user, kind: :match_analysis)
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save! }
  end
end
