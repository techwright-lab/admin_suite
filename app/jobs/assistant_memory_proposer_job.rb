# frozen_string_literal: true

class AssistantMemoryProposerJob < ApplicationJob
  queue_as :default

  def perform(user_id, thread_id, trace_id)
    user = User.find_by(id: user_id)
    thread = Assistant::ChatThread.find_by(id: thread_id)
    return unless user && thread

    Assistant::Memory::MemoryProposer.new(user: user, thread: thread, trace_id: trace_id).propose!
  end
end
