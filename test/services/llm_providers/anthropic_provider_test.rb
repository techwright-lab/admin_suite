# frozen_string_literal: true

require "test_helper"

module LlmProviders
  class AnthropicProviderTest < ActiveSupport::TestCase
    test "parse_message sanitizes tool_use blocks (no _json_buf, input is a hash)" do
      provider = LlmProviders::AnthropicProvider.new

      fake_message = Struct.new(:to_h).new(
        {
          "content" => [
            { "type" => "text", "text" => "Hello" },
            {
              "type" => "tool_use",
              "id" => "toolu_test",
              "name" => "list_interview_applications",
              "input" => "{\"status\":\"active\"}",
              "_json_buf" => "SHOULD_NOT_LEAK"
            }
          ]
        }
      )

      parsed = provider.send(:parse_message, fake_message)
      blocks = parsed[:content_blocks]

      tool_block = blocks.find { |b| b["type"] == "tool_use" }
      assert tool_block.present?
      assert_equal "toolu_test", tool_block["id"]
      assert_equal "list_interview_applications", tool_block["name"]
      assert tool_block["input"].is_a?(Hash)
      assert_not tool_block.key?("_json_buf")
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module LlmProviders
  class AnthropicProviderTest < ActiveSupport::TestCase
    setup do
      @provider = AnthropicProvider.new
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

    test "build_content_with_media returns array with media blocks" do
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

      # First block should be image
      assert_equal "image", result[0][:type]
      assert_equal "base64", result[0][:source][:type]
      assert_equal "image/png", result[0][:source][:media_type]

      # Second block should be text
      assert_equal "text", result[1][:type]
      assert_equal "Describe this image", result[1][:text]
    end

    # build_media_block tests
    test "build_media_block returns nil for unsupported media type" do
      media = { type: "image", media_type: "video/mp4", data: "abc" }

      result = @provider.send(:build_media_block, media)

      assert_nil result
    end

    test "build_media_block builds image block with base64 source" do
      media = {
        type: "image",
        source_type: "base64",
        media_type: "image/jpeg",
        data: "base64data=="
      }

      result = @provider.send(:build_media_block, media)

      assert_equal "image", result[:type]
      assert_equal "base64", result[:source][:type]
      assert_equal "image/jpeg", result[:source][:media_type]
      assert_equal "base64data==", result[:source][:data]
    end

    test "build_media_block builds image block with URL source" do
      media = {
        type: "image",
        source_type: "url",
        media_type: "image/png",
        url: "https://example.com/image.png"
      }

      result = @provider.send(:build_media_block, media)

      assert_equal "image", result[:type]
      assert_equal "url", result[:source][:type]
      assert_equal "https://example.com/image.png", result[:source][:url]
    end

    test "build_media_block builds document block for PDF" do
      media = {
        type: "document",
        source_type: "base64",
        media_type: "application/pdf",
        data: "JVBERi0xLjQ="
      }

      result = @provider.send(:build_media_block, media)

      assert_equal "document", result[:type]
      assert_equal "base64", result[:source][:type]
      assert_equal "application/pdf", result[:source][:media_type]
      assert_equal "JVBERi0xLjQ=", result[:source][:data]
    end

    test "build_media_block infers document type from media_type" do
      media = {
        type: "image", # Wrong type, but media_type is PDF
        source_type: "base64",
        media_type: "application/pdf",
        data: "JVBERi0xLjQ="
      }

      result = @provider.send(:build_media_block, media)

      # Should create document block, not image
      assert_equal "document", result[:type]
    end

    test "build_media_block includes cache_control for documents when provided" do
      media = {
        type: "document",
        source_type: "base64",
        media_type: "application/pdf",
        data: "JVBERi0xLjQ=",
        cache_control: { type: "ephemeral" }
      }

      result = @provider.send(:build_media_block, media)

      assert_equal({ type: "ephemeral" }, result[:cache_control])
    end

    # DOCX handling tests
    test "build_media_block returns text block for DOCX with pre-extracted text" do
      media = {
        type: "document",
        media_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        extracted_text: "This is the resume content",
        filename: "resume.docx"
      }

      result = @provider.send(:build_media_block, media)

      assert_equal "text", result[:type]
      assert_includes result[:text], "This is the resume content"
      assert_includes result[:text], "Document: resume.docx"
    end

    test "build_text_block_from_document uses extracted_text when provided" do
      media = {
        extracted_text: "Pre-extracted content",
        filename: "test.docx"
      }

      result = @provider.send(:build_text_block_from_document, media)

      assert_equal "text", result[:type]
      assert_includes result[:text], "Pre-extracted content"
      assert_includes result[:text], "Document: test.docx"
    end

    test "format_document_text includes filename when provided" do
      result = @provider.send(:format_document_text, "Content", "resume.docx")

      assert_includes result, "Document: resume.docx"
      assert_includes result, "Content"
      assert_includes result, "End of Document"
    end

    test "format_document_text uses generic header when no filename" do
      result = @provider.send(:format_document_text, "Content", nil)

      assert_includes result, "Document Content"
      assert_includes result, "Content"
    end

    # build_messages tests
    test "build_messages returns simple user message when no media" do
      result = @provider.send(:build_messages, "Hello", {})

      assert_equal 1, result.size
      assert_equal "user", result[0][:role]
      assert_equal "Hello", result[0][:content]
    end

    test "build_messages includes media in user message" do
      media = [
        { type: "image", source_type: "base64", media_type: "image/png", data: "abc=" }
      ]

      result = @provider.send(:build_messages, "What's in this image?", { media: media })

      assert_equal 1, result.size
      assert_equal "user", result[0][:role]
      assert_kind_of Array, result[0][:content]
      assert_equal 2, result[0][:content].size
    end

    test "build_messages uses provided messages when present" do
      messages = [
        { role: "user", content: "Hello" },
        { role: "assistant", content: "Hi there!" },
        { role: "user", content: "How are you?" }
      ]

      result = @provider.send(:build_messages, nil, { messages: messages })

      assert_equal 3, result.size
      assert_equal "How are you?", result[2][:content]
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
      assert_equal 2, result[2][:content].size
      assert_equal "image", result[2][:content][0][:type]
      assert_equal "text", result[2][:content][1][:type]
      assert_equal "Look at this", result[2][:content][1][:text]

      # First user message should be unchanged
      assert_equal "First message", result[0][:content]
    end

    test "inject_media_into_messages handles messages with string keys" do
      messages = [
        { "role" => "user", "content" => "Check this out" }
      ]
      media = [
        { type: "image", source_type: "base64", media_type: "image/jpeg", data: "xyz=" }
      ]

      result = @provider.send(:inject_media_into_messages, messages, media)

      assert_kind_of Array, result[0][:content]
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

      # Should have 2 blocks: image first, then existing text
      content = result[0][:content]
      assert_equal 2, content.size
      assert_equal "image", content[0][:type]
      assert_equal "text", content[1][:type]
      assert_equal "Existing text", content[1][:text]
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
      assert_equal 4, result.size # 3 media + 1 text

      assert_equal "image", result[0][:type]
      assert_equal "image", result[1][:type]
      assert_equal "document", result[2][:type]
      assert_equal "text", result[3][:type]
    end

    # Edge cases
    test "build_media_block returns nil when data and url are both missing" do
      media = { type: "image", source_type: "base64", media_type: "image/png" }

      result = @provider.send(:build_media_block, media)

      assert_nil result
    end

    test "build_content_with_media handles text-only when media blocks are invalid" do
      media = [
        { type: "image", media_type: "video/mp4", data: "invalid" } # Unsupported type
      ]

      result = @provider.send(:build_content_with_media, "Just text", media)

      # Should only have text block since media was invalid
      assert_kind_of Array, result
      assert_equal 1, result.size
      assert_equal "text", result[0][:type]
    end
  end
end
