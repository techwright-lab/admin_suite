# frozen_string_literal: true

require "test_helper"

class InterviewRoundPrepArtifactTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @company = create(:company)
    @job_role = create(:job_role)
    @application = create(:interview_application, user: @user, company: @company, job_role: @job_role)
    @round = create(:interview_round, interview_application: @application)
  end

  test "validates presence of interview_round" do
    artifact = InterviewRoundPrepArtifact.new(kind: :comprehensive)
    assert_not artifact.valid?
    assert_includes artifact.errors[:interview_round], "can't be blank"
  end

  test "validates presence of kind" do
    artifact = InterviewRoundPrepArtifact.new(interview_round: @round)
    assert_not artifact.valid?
    assert_includes artifact.errors[:kind], "can't be blank"
  end

  test "validates kind inclusion" do
    artifact = InterviewRoundPrepArtifact.new(interview_round: @round, kind: "invalid_kind")
    assert_not artifact.valid?
    assert_includes artifact.errors[:kind], "is not included in the list"
  end

  test "validates uniqueness of kind per round" do
    InterviewRoundPrepArtifact.create!(interview_round: @round, kind: :comprehensive)
    duplicate = InterviewRoundPrepArtifact.new(interview_round: @round, kind: :comprehensive)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:kind], "already exists for this round"
  end

  test "default status is pending" do
    artifact = InterviewRoundPrepArtifact.create!(interview_round: @round, kind: :comprehensive)
    assert_equal "pending", artifact.status
  end

  test "stale? returns true when digest differs" do
    artifact = InterviewRoundPrepArtifact.create!(
      interview_round: @round,
      kind: :comprehensive,
      inputs_digest: "old_digest"
    )
    assert artifact.stale?("new_digest")
    assert_not artifact.stale?("old_digest")
  end

  test "complete! updates artifact with content and status" do
    artifact = InterviewRoundPrepArtifact.create!(interview_round: @round, kind: :comprehensive)
    content = { round_summary: { type: "coding" } }

    artifact.complete!(content, digest: "test_digest")

    assert_equal "completed", artifact.status
    assert_equal "test_digest", artifact.inputs_digest
    assert_not_nil artifact.generated_at
    # store_accessor uses string keys internally
    assert_equal({ "type" => "coding" }, artifact.round_summary)
  end

  test "fail! marks artifact as failed with error message" do
    artifact = InterviewRoundPrepArtifact.create!(interview_round: @round, kind: :comprehensive)

    artifact.fail!("Test error")

    assert_equal "failed", artifact.status
    assert_equal "Test error", artifact.content["error"]
  end

  test "has_content? returns true for completed artifacts with content" do
    artifact = InterviewRoundPrepArtifact.create!(interview_round: @round, kind: :comprehensive)
    assert_not artifact.has_content?

    artifact.complete!({ round_summary: { type: "coding" } })
    assert artifact.has_content?

    # Failed artifacts don't have content
    artifact.fail!("Error")
    assert_not artifact.has_content?
  end

  test "find_or_initialize_for returns existing or new artifact" do
    # First call creates new
    artifact1 = InterviewRoundPrepArtifact.find_or_initialize_for(interview_round: @round, kind: :comprehensive)
    assert artifact1.new_record?
    artifact1.save!

    # Second call finds existing
    artifact2 = InterviewRoundPrepArtifact.find_or_initialize_for(interview_round: @round, kind: :comprehensive)
    assert_not artifact2.new_record?
    assert_equal artifact1.id, artifact2.id
  end

  test "store_accessor provides access to content fields" do
    artifact = InterviewRoundPrepArtifact.create!(
      interview_round: @round,
      kind: :comprehensive,
      content: {
        "round_summary" => { "type" => "coding" },
        "expected_questions" => [ { "category" => "Arrays" } ],
        "preparation_checklist" => [ "Review data structures" ]
      }
    )

    assert_equal({ "type" => "coding" }, artifact.round_summary)
    assert_equal [ { "category" => "Arrays" } ], artifact.expected_questions
    assert_equal [ "Review data structures" ], artifact.preparation_checklist
  end
end
