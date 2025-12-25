# frozen_string_literal: true

class AssistantThreadSummarizerJob < ApplicationJob
  queue_as :default

  def perform(thread_id)
    thread = Assistant::ChatThread.find_by(id: thread_id)
    return unless thread

    Assistant::Memory::ThreadSummarizer.new(thread: thread).maybe_summarize!
  end
end
