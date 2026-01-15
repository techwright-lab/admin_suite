# frozen_string_literal: true

require "test_helper"

class InterviewApplicationsControllerTest < ActionDispatch::IntegrationTest
  test "overview shows extracted links and round actions" do
    user = create(:user)
    sign_in_as(user)

    company = create(:company, name: "Toptal", website: "https://www.toptal.com")
    application = create(:interview_application, user:, company:)
    round = create(:interview_round, :upcoming, interview_application: application, video_link: "https://meet.example.com/round")
    connected_account = create(:connected_account, user:)

    extracted_data = {
      "signal_company_careers_url" => "https://www.toptal.com/careers",
      "signal_action_links" => [
        { "url" => "https://zoom.us/j/123", "action_label" => "Join Toptal Zoom interview", "priority" => 1 },
        { "url" => "https://goodtime.io/reschedule/abc", "action_label" => "Reschedule interview", "priority" => 1 },
        { "url" => "https://www.toptal.com/culture", "action_label" => "Learn About Toptal Culture", "priority" => 3 }
      ]
    }

    create(
      :synced_email,
      user:,
      connected_account:,
      interview_application: application,
      extracted_data:,
      status: :processed,
      email_type: "interview_invite"
    )

    get interview_application_path(application)
    assert_response :success

    assert_includes response.body, "Join Interview"
    assert_includes response.body, "Reschedule Interview"
    assert_includes response.body, round.video_link

    assert_includes response.body, "Careers Page"
    assert_includes response.body, "https://www.toptal.com/careers"

    assert_includes response.body, "Useful Links"
    assert_includes response.body, "Learn About Toptal Culture"
  end
end

