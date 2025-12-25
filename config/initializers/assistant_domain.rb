# frozen_string_literal: true

# Configure Zeitwerk to treat the assistant domain as a first-class namespace
# while keeping internal folders (`models/`, `services/`, etc.) out of the constant path.
#
# This allows:
# - app/domains/assistant/models/chat_thread.rb  => Assistant::ChatThread
# - app/domains/assistant/services/chat/...     => Assistant::Chat::...
Rails.autoloaders.main.tap do |loader|
  assistant_root = Rails.root.join("app/domains/assistant")

  loader.collapse(assistant_root.join("models"))
  loader.collapse(assistant_root.join("services"))
  loader.collapse(assistant_root.join("policies"))
end
