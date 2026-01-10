# frozen_string_literal: true

require "test_helper"

module LlmProviders
  class OpenaiProviderTest < ActiveSupport::TestCase
    setup do
      @provider = OpenaiProvider.new
    end

    # Media support capability tests
    test "supports_media? returns true" do
      assert @provider.supports_media?
    end

    test "supported_media_types includes image types" do
      types = @provider.supported_media_types

      assert_includes types, "image/jpeg"
      assert_includes types, "image/png"
      assert_includes types, "image/gif"
      assert_includes types, "image/webp"
    end

    test "supported_media_types includes PDF" do
      types = @provider.supported_media_types

      assert_includes types, "application/pdf"
    end

    test "supported_media_types includes DOCX" do
      types = @provider.supported_media_types

      assert_includes types, "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    end

    # build_content_with_media tests
    test "build_content_with_media returns string when no media" do
      result = @provider.send(:build_content_with_media, "Hello world", nil)

      assert_equal "Hello world", result
    end

    test "build_content_with_media returns string when media is empty array" do
      result = @provider.send(:build_content_with_media, "Hello world", [])

      assert_equal "Hello world", result
    end

    test "build_content_with_media returns array with media blocks for images" do
      media = [
        {
          type: "image",
          source_type: "base64",
          media_type: "image/png",
          data: "iVBORw0KGgo="
        }
      ]

      result = @provider.send(:build_content_with_media, "Describe this image", media)

      assert_kind_of Array, result
      assert_equal 2, result.size

      # First block should be text (OpenAI puts text first)
      assert_equal "text", result[0][:type]
      assert_equal "Describe this image", result[0][:text]

      # Second block should be image_url
      assert_equal "image_url", result[1][:type]
      assert_match(/^data:image\/png;base64,/, result[1][:image_url][:url])
    end

    # build_media_block tests
    test "build_media_block returns nil for unsupported media type" do
      media = { type: "image", media_type: "video/mp4", data: "abc" }

      result = @provider.send(:build_media_block, media)

      assert_nil result
    end

    test "build_media_block builds image_url block with base64 source" do
      media = {
        type: "image",
        source_type: "base64",
        media_type: "image/jpeg",
        data: "base64data=="
      }

      result = @provider.send(:build_media_block, media)

      assert_equal "image_url", result[:type]
      assert_equal "data:image/jpeg;base64,base64data==", result[:image_url][:url]
      assert_equal "auto", result[:image_url][:detail]
    end

    test "build_media_block builds image_url block with URL source" do
      media = {
        type: "image",
        source_type: "url",
        media_type: "image/png",
        url: "https://example.com/image.png"
      }

      result = @provider.send(:build_media_block, media)

      assert_equal "image_url", result[:type]
      assert_equal "https://example.com/image.png", result[:image_url][:url]
    end

    test "build_media_block respects custom detail level" do
      media = {
        type: "image",
        source_type: "url",
        media_type: "image/png",
        url: "https://example.com/image.png",
        detail: "high"
      }

      result = @provider.send(:build_media_block, media)

      assert_equal "high", result[:image_url][:detail]
    end

    test "build_media_block builds input_file block for PDF with base64" do
      media = {
        type: "document",
        source_type: "base64",
        media_type: "application/pdf",
        data: "JVBERi0xLjQ="
      }

      result = @provider.send(:build_media_block, media)

      assert_equal "input_file", result[:type]
      assert_equal "document.pdf", result[:filename]
      assert_match(/^data:application\/pdf;base64,/, result[:file_data])
    end

    test "build_media_block builds input_file block for DOCX with base64" do
      media = {
        type: "document",
        source_type: "base64",
        media_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        data: "UEsDBBQA="
      }

      result = @provider.send(:build_media_block, media)

      assert_equal "input_file", result[:type]
      assert_equal "document.docx", result[:filename]
    end

    test "build_media_block uses file_id when provided" do
      media = {
        type: "document",
        media_type: "application/pdf",
        file_id: "file-abc123"
      }

      result = @provider.send(:build_media_block, media)

      assert_equal "input_file", result[:type]
      assert_equal "file-abc123", result[:file_id]
    end

    test "build_media_block uses custom filename when provided" do
      media = {
        type: "document",
        source_type: "base64",
        media_type: "application/pdf",
        data: "JVBERi0xLjQ=",
        filename: "resume.pdf"
      }

      result = @provider.send(:build_media_block, media)

      assert_equal "resume.pdf", result[:filename]
    end

    # build_input tests
    test "build_input returns simple user message when no media" do
      result = @provider.send(:build_input, "Hello", {})

      assert_equal 1, result.size
      assert_equal "user", result[0][:role]
      assert_equal "Hello", result[0][:content]
    end

    test "build_input includes media in user message" do
      media = [
        { type: "image", source_type: "base64", media_type: "image/png", data: "abc=" }
      ]

      result = @provider.send(:build_input, "What's in this image?", { media: media })

      assert_equal 1, result.size
      assert_equal "user", result[0][:role]
      assert_kind_of Array, result[0][:content]
      assert_equal 2, result[0][:content].size
    end

    test "build_input uses provided messages when present" do
      messages = [
        { role: "user", content: "Hello" },
        { role: "assistant", content: "Hi there!" },
        { role: "user", content: "How are you?" }
      ]

      result = @provider.send(:build_input, nil, { messages: messages })

      assert_equal 3, result.size
      assert_equal "How are you?", result[2][:content]
    end

    test "build_input injects media into messages" do
      messages = [
        { role: "user", content: "Look at this" }
      ]
      media = [
        { type: "image", source_type: "base64", media_type: "image/png", data: "abc=" }
      ]

      result = @provider.send(:build_input, nil, { messages: messages, media: media })

      assert_kind_of Array, result[0][:content]
    end

    # inject_media_into_messages tests
    test "inject_media_into_messages adds media to last user message" do
      messages = [
        { role: "user", content: "First message" },
        { role: "assistant", content: "Response" },
        { role: "user", content: "Look at this" }
      ]
      media = [
        { type: "image", source_type: "base64", media_type: "image/png", data: "abc=" }
      ]

      result = @provider.send(:inject_media_into_messages, messages, media)

      # Last user message should have media
      assert_kind_of Array, result[2][:content]

      # First user message should be unchanged
      assert_equal "First message", result[0][:content]
    end

    test "inject_media_into_messages returns unchanged if no user messages" do
      messages = [
        { role: "assistant", content: "I'm the assistant" }
      ]
      media = [
        { type: "image", source_type: "base64", media_type: "image/png", data: "abc=" }
      ]

      result = @provider.send(:inject_media_into_messages, messages, media)

      assert_equal messages, result
    end

    test "inject_media_into_messages handles existing content blocks" do
      messages = [
        {
          role: "user",
          content: [
            { type: "text", text: "Existing text" }
          ]
        }
      ]
      media = [
        { type: "image", source_type: "base64", media_type: "image/png", data: "abc=" }
      ]

      result = @provider.send(:inject_media_into_messages, messages, media)

      # Should have 2 blocks: existing text + image
      content = result[0][:content]
      assert_equal 2, content.size
      assert_equal "text", content[0][:type]
      assert_equal "image_url", content[1][:type]
    end

    # Multiple media items test
    test "build_content_with_media handles multiple media items" do
      media = [
        { type: "image", source_type: "base64", media_type: "image/png", data: "img1=" },
        { type: "image", source_type: "base64", media_type: "image/jpeg", data: "img2=" },
        { type: "document", source_type: "base64", media_type: "application/pdf", data: "pdf=" }
      ]

      result = @provider.send(:build_content_with_media, "Analyze these files", media)

      assert_kind_of Array, result
      assert_equal 4, result.size # 1 text + 3 media

      assert_equal "text", result[0][:type]
      assert_equal "image_url", result[1][:type]
      assert_equal "image_url", result[2][:type]
      assert_equal "input_file", result[3][:type]
    end

    # Edge cases
    test "build_media_block returns nil when data and url are both missing" do
      media = { type: "image", source_type: "base64", media_type: "image/png" }

      result = @provider.send(:build_media_block, media)

      assert_nil result
    end

    test "default_filename_for returns appropriate filenames" do
      assert_equal "document.pdf", @provider.send(:default_filename_for, "application/pdf")
      assert_equal "document.docx", @provider.send(:default_filename_for, "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
      assert_equal "file", @provider.send(:default_filename_for, "unknown/type")
    end
  end
end
