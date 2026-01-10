# frozen_string_literal: true

require "test_helper"

module Assistant
  module Chat
    module Components
      class LlmResponderTest < ActiveSupport::TestCase
        setup do
          @user = create(:user, name: "Test User")
          @thread = Assistant::ChatThread.create!(user: @user, title: "Test Thread", status: "open")
        end

        test "build_system_prompt_with_context includes user name" do
          context = {
            user: { id: @user.id, name: "Test User" }
          }

          responder = LlmResponder.new(
            user: @user,
            trace_id: SecureRandom.uuid,
            question: "Help me",
            context: context,
            allowed_tools: [],
            thread: @thread
          )

          prompt = responder.send(:build_system_prompt_with_context)

          assert_includes prompt, "User: Test User"
        end

        test "build_system_prompt_with_context includes career context" do
          context = {
            user: { id: @user.id, name: "Test User" },
            career: {
              resume: {
                profile_summary: "Experienced developer",
                strengths: [ "Problem solving", "Leadership" ],
                domains: [ "FinTech", "SaaS" ]
              },
              work_history: [
                {
                  title: "Senior Engineer",
                  company: "TechCorp",
                  current: true,
                  start_date: "Jan 2022",
                  end_date: "Present",
                  skills: [ "Ruby", "Rails" ],
                  highlights: [ "Led team of 5" ]
                }
              ],
              targets: {
                roles: [ "Staff Engineer" ],
                companies: [ "Google" ]
              }
            }
          }

          responder = LlmResponder.new(
            user: @user,
            trace_id: SecureRandom.uuid,
            question: "Help me",
            context: context,
            allowed_tools: [],
            thread: @thread
          )

          prompt = responder.send(:build_system_prompt_with_context)

          # Verify profile summary is included
          assert_includes prompt, "Profile Summary: Experienced developer"

          # Verify strengths are included
          assert_includes prompt, "Strengths: Problem solving, Leadership"

          # Verify domains are included
          assert_includes prompt, "Domains: FinTech, SaaS"

          # Verify work history is included
          assert_includes prompt, "Senior Engineer at TechCorp"
          assert_includes prompt, "(Current)"
          assert_includes prompt, "Skills: Ruby, Rails"
          assert_includes prompt, "Led team of 5"

          # Verify targets are included
          assert_includes prompt, "Target Roles: Staff Engineer"
          assert_includes prompt, "Target Companies: Google"
        end

        test "build_system_prompt_with_context includes full resume when provided" do
          context = {
            user: { id: @user.id, name: "Test User" },
            career: {
              resume: {
                profile_summary: "Developer",
                full_text: "This is my full resume content with lots of details."
              }
            }
          }

          responder = LlmResponder.new(
            user: @user,
            trace_id: SecureRandom.uuid,
            question: "Help me with my resume",
            context: context,
            allowed_tools: [],
            thread: @thread
          )

          prompt = responder.send(:build_system_prompt_with_context)

          assert_includes prompt, "--- Full Resume ---"
          assert_includes prompt, "This is my full resume content"
          assert_includes prompt, "--- End Resume ---"
        end

        test "build_system_prompt_with_context includes skills" do
          context = {
            user: { id: @user.id, name: "Test User" },
            skills: {
              top_skills: [
                { name: "Ruby" },
                { name: "JavaScript" },
                { name: "Python" }
              ]
            }
          }

          responder = LlmResponder.new(
            user: @user,
            trace_id: SecureRandom.uuid,
            question: "What skills should I focus on?",
            context: context,
            allowed_tools: [],
            thread: @thread
          )

          prompt = responder.send(:build_system_prompt_with_context)

          assert_includes prompt, "Top Skills: Ruby, JavaScript, Python"
        end

        test "build_system_prompt_with_context includes pipeline status" do
          context = {
            user: { id: @user.id, name: "Test User" },
            pipeline: {
              interview_applications_count: 5,
              recent_interview_applications: [
                { job_role: "Engineer", company: "Acme", status: "applied" }
              ]
            }
          }

          responder = LlmResponder.new(
            user: @user,
            trace_id: SecureRandom.uuid,
            question: "How's my job search going?",
            context: context,
            allowed_tools: [],
            thread: @thread
          )

          prompt = responder.send(:build_system_prompt_with_context)

          assert_includes prompt, "Pipeline: 5 applications"
          assert_includes prompt, "Engineer at Acme (applied)"
        end

        test "build_system_prompt_with_context includes page context" do
          context = {
            user: { id: @user.id, name: "Test User" },
            page: {
              resume_id: 123,
              job_listing_id: 456
            }
          }

          responder = LlmResponder.new(
            user: @user,
            trace_id: SecureRandom.uuid,
            question: "Help me",
            context: context,
            allowed_tools: [],
            thread: @thread
          )

          prompt = responder.send(:build_system_prompt_with_context)

          assert_includes prompt, "Current Page:"
          assert_includes prompt, "resume_id: 123"
          assert_includes prompt, "job_listing_id: 456"
        end

        test "responder accepts media attachments" do
          context = { user: { id: @user.id, name: "Test User" } }
          media = [
            { type: "document", media_type: "application/pdf", data: "base64data" }
          ]

          responder = LlmResponder.new(
            user: @user,
            trace_id: SecureRandom.uuid,
            question: "Analyze this resume",
            context: context,
            allowed_tools: [],
            thread: @thread,
            media: media
          )

          # Verify media is stored
          assert_equal 1, responder.send(:media).size
          assert_equal "application/pdf", responder.send(:media).first[:media_type]
        end

        test "responder handles nil media gracefully" do
          context = { user: { id: @user.id, name: "Test User" } }

          responder = LlmResponder.new(
            user: @user,
            trace_id: SecureRandom.uuid,
            question: "Help me",
            context: context,
            allowed_tools: [],
            thread: @thread,
            media: nil
          )

          assert_equal [], responder.send(:media)
        end
      end
    end
  end
end
