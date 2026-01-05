# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class Billing::CheckoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in_as(@user)
  end

  test "redirects to hosted checkout url" do
    plan = create(:billing_plan, :pro, key: "pro", published: true)
    create(:billing_provider_mapping, plan: plan, external_variant_id: "variant_1", metadata: { "store_id" => "store_1" })

    ENV["LEMONSQUEEZY_API_KEY"] = "api_key"

    stub_request(:post, "https://api.lemonsqueezy.com/v1/checkouts")
      .to_return(status: 201, body: { data: { attributes: { url: "https://checkout.lemonsqueezy.com/abc" } } }.to_json, headers: { "Content-Type" => "application/vnd.api+json" })

    post billing_checkout_path(plan_key: "pro")

    assert_response :redirect
    assert_match %r{\Ahttps://checkout\.lemonsqueezy\.com/}, response.location
  end
end


