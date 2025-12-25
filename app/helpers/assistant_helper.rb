# frozen_string_literal: true

# Helper methods for assistant chat views.
module AssistantHelper
  # Renders markdown content with syntax highlighting for assistant messages.
  # User messages are returned as plain text for simplicity.
  #
  # @param message [Assistant::ChatMessage] The chat message
  # @return [String] Safe HTML string
  def render_chat_message(message)
    content = message.content.to_s

    if message.role == "assistant"
      render_assistant_markdown(content)
    else
      # User messages: simple HTML escape with line breaks
      simple_format(h(content), {}, wrapper_tag: "span")
    end
  end

  # Renders markdown to HTML with syntax highlighting for assistant responses.
  #
  # @param text [String] The markdown text
  # @return [String] Safe HTML string
  def render_assistant_markdown(text)
    return "" if text.blank?

    # Use the existing MarkdownRenderer service
    html = MarkdownRenderer.render(text)

    # Wrap in a container with chat-specific prose styling
    content_tag(:div, html, class: "chat-prose")
  end
end

