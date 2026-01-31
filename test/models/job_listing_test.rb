# frozen_string_literal: true

require "test_helper"

class JobListingTest < ActiveSupport::TestCase
  def setup
    @company = create(:company)
    @job_role = create(:job_role)
    @listing = build(:job_listing, company: @company, job_role: @job_role)
  end

  # Validations
  test "valid listing" do
    assert @listing.valid?
  end

  test "requires company" do
    @listing.company = nil
    assert_not @listing.valid?
    assert_includes @listing.errors[:company], "can't be blank"
  end

  test "requires job_role" do
    @listing.job_role = nil
    assert_not @listing.valid?
    assert_includes @listing.errors[:job_role], "can't be blank"
  end

  # Enums
  test "has remote_type enum" do
    assert_respond_to @listing, :remote_type
    assert_respond_to @listing, :on_site?
    assert_respond_to @listing, :hybrid?
    assert_respond_to @listing, :remote?
  end

  test "has status enum" do
    assert_respond_to @listing, :status
    assert_respond_to @listing, :draft?
    assert_respond_to @listing, :active?
    assert_respond_to @listing, :closed?
  end

  test "defaults to on_site remote_type" do
    listing = JobListing.create!(company: @company, job_role: @job_role)
    assert listing.on_site?
  end

  test "defaults to active status" do
    listing = JobListing.create!(company: @company, job_role: @job_role)
    assert listing.active?
  end

  # Associations
  test "belongs to company" do
    assert_respond_to @listing, :company
    assert_instance_of Company, @listing.company
  end

  test "belongs to job_role" do
    assert_respond_to @listing, :job_role
    assert_instance_of JobRole, @listing.job_role
  end

  test "has many interview_applications" do
    listing = create(:job_listing, company: @company, job_role: @job_role)
    user = create(:user)
    app = create(:interview_application, user: user, company: @company, job_role: @job_role, job_listing: listing)

    assert_includes listing.interview_applications, app
  end

  # JSONB fields
  test "custom_sections defaults to empty hash" do
    listing = JobListing.new
    assert_equal({}, listing.custom_sections)
  end

  test "scraped_data defaults to empty hash" do
    listing = JobListing.new
    assert_equal({}, listing.scraped_data)
  end

  test "can store custom_sections as JSONB" do
    listing = create(:job_listing, :with_custom_sections, company: @company, job_role: @job_role)

    assert_instance_of Hash, listing.custom_sections
    assert listing.custom_sections.key?("what_youll_do")
  end

  test "can store scraped_data as JSONB" do
    listing = create(:job_listing, :with_scraped_data, company: @company, job_role: @job_role)

    assert_instance_of Hash, listing.scraped_data
    assert listing.scraped_data.key?("scraped_at")
  end

  # Scopes
  test "active scope returns only active listings" do
    active = create(:job_listing, company: @company, job_role: @job_role, status: :active)
    closed = create(:job_listing, :closed, company: @company, job_role: @job_role)

    assert_includes JobListing.active, active
    assert_not_includes JobListing.active, closed
  end

  test "closed scope returns only closed listings" do
    active = create(:job_listing, company: @company, job_role: @job_role, status: :active)
    closed = create(:job_listing, :closed, company: @company, job_role: @job_role)

    assert_includes JobListing.closed, closed
    assert_not_includes JobListing.closed, active
  end

  test "remote scope returns only remote listings" do
    remote = create(:job_listing, :remote, company: @company, job_role: @job_role)
    on_site = create(:job_listing, :on_site, company: @company, job_role: @job_role)

    assert_includes JobListing.remote, remote
    assert_not_includes JobListing.remote, on_site
  end

  test "recent scope orders by created_at desc" do
    listing1 = create(:job_listing, company: @company, job_role: @job_role, created_at: 2.days.ago)
    listing2 = create(:job_listing, company: @company, job_role: @job_role, created_at: 1.day.ago)

    assert_equal [ listing2, listing1 ], JobListing.recent.to_a
  end

  # Helper methods
  test "#display_title returns title or job_role title" do
    @listing.title = "Custom Title"
    assert_equal "Custom Title", @listing.display_title

    @listing.title = nil
    assert_equal @job_role.title, @listing.display_title
  end

  test "#salary_range returns formatted salary range" do
    @listing.salary_min = 100000
    @listing.salary_max = 150000
    @listing.salary_currency = "USD"

    assert_equal "$100,000 - $150,000 USD", @listing.salary_range
  end

  test "#salary_range returns nil when no salary info" do
    @listing.salary_min = nil
    @listing.salary_max = nil

    assert_nil @listing.salary_range
  end

  test "#salary_range returns nil when salary is implausible" do
    @listing.salary_min = 89
    @listing.salary_max = 7
    @listing.salary_currency = "USD"

    assert_nil @listing.salary_range
  end

  test "#salary_range returns nil when currency is invalid" do
    @listing.salary_min = 120000
    @listing.salary_max = 150000
    @listing.salary_currency = "US"

    assert_nil @listing.salary_range
  end

  test "#has_custom_sections? returns true when custom_sections present" do
    listing = create(:job_listing, :with_custom_sections, company: @company, job_role: @job_role)
    assert listing.has_custom_sections?
  end

  test "#has_custom_sections? returns false when custom_sections empty" do
    listing = create(:job_listing, company: @company, job_role: @job_role)
    assert_not listing.has_custom_sections?
  end

  test "#scraped? returns true when scraped_data present" do
    listing = create(:job_listing, :with_scraped_data, company: @company, job_role: @job_role)
    assert listing.scraped?
  end

  test "#scraped? returns false when scraped_data empty" do
    listing = create(:job_listing, company: @company, job_role: @job_role)
    assert_not listing.scraped?
  end

  test "#remote_type_display returns formatted remote type" do
    @listing.remote_type = :on_site
    assert_equal "On Site", @listing.remote_type_display

    @listing.remote_type = :remote
    assert_equal "Remote", @listing.remote_type_display

    @listing.remote_type = :hybrid
    assert_equal "Hybrid", @listing.remote_type_display
  end

  test "#location_display returns location with remote type" do
    @listing.location = "San Francisco, CA"
    @listing.remote_type = :hybrid

    assert_equal "San Francisco, CA (Hybrid)", @listing.location_display
  end

  test "#location_display returns only remote type when no location" do
    @listing.location = nil
    @listing.remote_type = :remote

    assert_equal "Remote", @listing.location_display
  end

  # Limited extraction methods
  test "#job_board returns job_board from scraped_data" do
    @listing.scraped_data = { "job_board" => "linkedin" }
    assert_equal "linkedin", @listing.job_board
  end

  test "#job_board falls back to job_board_id" do
    @listing.scraped_data = {}
    @listing.job_board_id = "greenhouse"
    assert_equal "greenhouse", @listing.job_board
  end

  test "#extraction_quality returns quality from scraped_data" do
    @listing.scraped_data = { "extraction_quality" => "limited" }
    assert_equal "limited", @listing.extraction_quality
  end

  test "#extraction_quality defaults to full" do
    @listing.scraped_data = {}
    assert_equal "full", @listing.extraction_quality
  end

  test "#limited_extraction? returns true for limited quality" do
    @listing.scraped_data = { "extraction_quality" => "limited" }
    assert @listing.limited_extraction?
  end

  test "#limited_extraction? returns true for LinkedIn job board" do
    @listing.scraped_data = { "job_board" => "linkedin" }
    assert @listing.limited_extraction?
  end

  test "#limited_extraction? returns true for Indeed job board" do
    @listing.scraped_data = { "job_board" => "indeed" }
    assert @listing.limited_extraction?
  end

  test "#limited_extraction? returns true for Glassdoor job board" do
    @listing.scraped_data = { "job_board" => "glassdoor" }
    assert @listing.limited_extraction?
  end

  test "#limited_extraction? returns false for Greenhouse job board" do
    @listing.scraped_data = { "job_board" => "greenhouse" }
    assert_not @listing.limited_extraction?
  end

  test "#needs_more_details? returns true for limited extraction" do
    @listing.scraped_data = { "extraction_quality" => "limited" }
    assert @listing.needs_more_details?
  end

  test "#needs_more_details? returns true when description is blank" do
    @listing.description = nil
    @listing.responsibilities = nil
    assert @listing.needs_more_details?
  end

  test "#needs_more_details? returns true for low confidence" do
    @listing.scraped_data = { "confidence_score" => 0.3 }
    assert @listing.needs_more_details?
  end

  test "#needs_more_details? returns false for complete listing" do
    @listing.description = "Full job description"
    @listing.scraped_data = { "confidence_score" => 0.8, "job_board" => "greenhouse" }
    assert_not @listing.needs_more_details?
  end

  test "#limited_extraction_reason returns message for LinkedIn" do
    @listing.scraped_data = { "job_board" => "linkedin" }
    reason = @listing.limited_extraction_reason

    assert_includes reason, "LinkedIn"
    assert_includes reason, "authentication"
  end

  test "#limited_extraction_reason returns message for Indeed" do
    @listing.scraped_data = { "job_board" => "indeed" }
    reason = @listing.limited_extraction_reason

    assert_includes reason, "Indeed"
  end

  test "#limited_extraction_reason returns nil for non-limited sources" do
    @listing.scraped_data = { "job_board" => "greenhouse" }
    assert_nil @listing.limited_extraction_reason
  end
end
