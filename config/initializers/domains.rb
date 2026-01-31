# frozen_string_literal: true

# Configure Zeitwerk to treat each domain under app/domains as a first-class namespace,
# while collapsing internal folders (models/, services/, policies/, tools/, contracts/, etc.)
# so they don't become part of the constant path.
#
# This allows:
# - app/domains/assistant/services/chat/turn_runner.rb => Assistant::Chat::TurnRunner
# - app/domains/signals/services/decisioning/...      => Signals::Decisioning::...
Rails.autoloaders.main.tap do |loader|
  domains = {
    # Mirror Assistant's original conventions:
    # - collapse models/, services/, policies/
    # - do NOT collapse tools/ or contracts/ (they are real namespaces: Assistant::Tools, Assistant::Contracts)
    "assistant" => %w[models services policies],
    # The Signals domain also has a real `Signals::Contracts::*` namespace, so we do NOT collapse `contracts/`.
    "signals" => %w[services]
  }

  domains.each do |domain_name, collapsed_dirs|
    root = Rails.root.join("app/domains", domain_name)
    collapsed_dirs.each do |dir|
      loader.collapse(root.join(dir))
    end
  end
end
