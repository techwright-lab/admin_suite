# frozen_string_literal: true

module Assistant
  class ToolExecutionsController < ApplicationController
    def approve
      tool_execution = scoped.find_by!(uuid: params[:uuid])

      if tool_execution.requires_confirmation? == false
        redirect_back fallback_location: assistant_thread_path(tool_execution.thread), alert: "This tool does not require approval."
        return
      end

      tool_execution = consolidate_batch_tool_executions!(tool_execution)

      enqueued = false
      tool_execution.with_lock do
        if %w[success running].include?(tool_execution.status)
          # no-op
        else
          tool_execution.update!(
            approved_by: (tool_execution.approved_by || Current.user),
            approved_at: (tool_execution.approved_at || Time.current),
            status: (tool_execution.status == "proposed" ? "queued" : tool_execution.status)
          )
          enqueued = (tool_execution.status == "queued")
        end
      end

      AssistantToolExecutionJob.perform_later(tool_execution.id, approved_by_id: Current.user.id) if enqueued

      if enqueued
        switch_originating_message_to_placeholder!(tool_execution)
        broadcast_tool_proposals(tool_execution.thread)
      end

      respond_to do |format|
        format.turbo_stream do
          streams = []
          streams << turbo_stream.replace(ActionView::RecordIdentifier.dom_id(tool_execution.thread, :tool_executions), partial: "assistant/threads/tool_proposals", locals: {
            thread: tool_execution.thread,
            tool_executions: tool_execution.thread.tool_executions.where(status: %w[proposed queued running]).order(created_at: :asc)
          })
          streams << turbo_stream.replace(ActionView::RecordIdentifier.dom_id(tool_execution.assistant_message), partial: "assistant/threads/message", locals: { message: tool_execution.assistant_message }) if enqueued
          render turbo_stream: streams
        end
        format.html { redirect_back fallback_location: assistant_thread_path(tool_execution.thread), notice: (enqueued ? "Approved and enqueued." : "Already running or finished.") }
      end
    end

    def enqueue
      tool_execution = scoped.find_by!(uuid: params[:uuid])

      if tool_execution.requires_confirmation? && tool_execution.approved_by_id.nil?
        redirect_back fallback_location: assistant_thread_path(tool_execution.thread), alert: "This tool requires approval before it can be executed."
        return
      end

      tool_execution = consolidate_batch_tool_executions!(tool_execution)

      enqueued = false
      tool_execution.with_lock do
        if tool_execution.status == "proposed"
          tool_execution.update!(status: "queued")
          enqueued = true
        end
      end

      AssistantToolExecutionJob.perform_later(tool_execution.id) if enqueued

      if enqueued
        switch_originating_message_to_placeholder!(tool_execution)
        broadcast_tool_proposals(tool_execution.thread)
      end

      respond_to do |format|
        format.turbo_stream do
          streams = []
          streams << turbo_stream.replace(ActionView::RecordIdentifier.dom_id(tool_execution.thread, :tool_executions), partial: "assistant/threads/tool_proposals", locals: {
            thread: tool_execution.thread,
            tool_executions: tool_execution.thread.tool_executions.where(status: %w[proposed queued running]).order(created_at: :asc)
          })
          streams << turbo_stream.replace(ActionView::RecordIdentifier.dom_id(tool_execution.assistant_message), partial: "assistant/threads/message", locals: { message: tool_execution.assistant_message }) if enqueued
          render turbo_stream: streams
        end
        format.html { redirect_back fallback_location: assistant_thread_path(tool_execution.thread), notice: (enqueued ? "Enqueued." : "Already queued or processed.") }
      end
    end

    private

    def scoped
      ::Assistant::ToolExecution.joins(:thread).where(assistant_threads: { user_id: Current.user.id })
    end

    def batchable_tool_key?(tool_key)
      tool_key.to_s.in?(%w[add_target_company add_target_job_role remove_target_company remove_target_job_role])
    end

    def consolidate_batch_tool_executions!(tool_execution)
      return tool_execution unless batchable_tool_key?(tool_execution.tool_key)

      siblings = scoped.where(
        thread_id: tool_execution.thread_id,
        assistant_message_id: tool_execution.assistant_message_id,
        tool_key: tool_execution.tool_key,
        status: "proposed",
        requires_confirmation: true,
        approved_by_id: nil
      ).order(created_at: :asc).to_a

      return tool_execution if siblings.size <= 1

      primary = siblings.first
      merged_args =
        case tool_execution.tool_key.to_s
        when "add_target_company"
          merge_company_args(siblings.map(&:args))
        when "add_target_job_role"
          merge_job_role_args(siblings.map(&:args))
        when "remove_target_company"
          merge_company_args(siblings.map(&:args))
        when "remove_target_job_role"
          merge_job_role_args(siblings.map(&:args))
        else
          primary.args
        end

      # Approving one means we approve the entire grouped action.
      now = Time.current
      primary.update!(args: merged_args)

      (siblings - [ primary ]).each do |te|
        te.update!(
          approved_by: Current.user,
          approved_at: now,
          status: "success",
          finished_at: now,
          result: {
            deduped: true,
            merged_into_tool_execution_id: primary.id
          },
          error: nil,
          metadata: (te.metadata || {}).merge("deduped" => true, "merged_into_tool_execution_id" => primary.id)
        )
      end

      primary
    end

    def merge_company_args(args_list)
      items = []
      Array(args_list).each do |args|
        args = args.is_a?(Hash) ? args : {}
        companies = args["companies"] || args[:companies]
        if companies.is_a?(Array)
          companies.each { |it| items << (it.is_a?(Hash) ? it : {}) }
        else
          items << args.slice("company_id", "company_name", "priority").merge(args.slice(:company_id, :company_name, :priority))
        end
      end

      uniq = {}
      items.each do |it|
        cid = (it["company_id"] || it[:company_id]).to_s.presence
        name = (it["company_name"] || it[:company_name]).to_s.strip
        key = cid.presence || "name:#{name.downcase}"
        next if key.blank? || key == "name:"
        pr = it["priority"] || it[:priority]
        uniq[key] ||= {}
        uniq[key]["company_id"] = cid.to_i if cid.present?
        uniq[key]["company_name"] = name if name.present?
        uniq[key]["priority"] = pr if pr.present?
      end

      { "companies" => uniq.values }
    end

    def merge_job_role_args(args_list)
      items = []
      Array(args_list).each do |args|
        args = args.is_a?(Hash) ? args : {}
        roles = args["job_roles"] || args[:job_roles]
        if roles.is_a?(Array)
          roles.each { |it| items << (it.is_a?(Hash) ? it : {}) }
        else
          items << args.slice("job_role_id", "job_role_title", "priority").merge(args.slice(:job_role_id, :job_role_title, :priority))
        end
      end

      uniq = {}
      items.each do |it|
        rid = (it["job_role_id"] || it[:job_role_id]).to_s.presence
        title = (it["job_role_title"] || it[:job_role_title]).to_s.strip
        key = rid.presence || "title:#{title.downcase}"
        next if key.blank? || key == "title:"
        pr = it["priority"] || it[:priority]
        uniq[key] ||= {}
        uniq[key]["job_role_id"] = rid.to_i if rid.present?
        uniq[key]["job_role_title"] = title if title.present?
        uniq[key]["priority"] = pr if pr.present?
      end

      { "job_roles" => uniq.values }
    end

    def switch_originating_message_to_placeholder!(tool_execution)
      msg = tool_execution.assistant_message
      return if msg.nil?

      msg.update!(
        content: "Working on it — I’m fetching the latest info now.",
        metadata: msg.metadata.merge("pending_tool_followup" => true)
      )
    end

    def broadcast_tool_proposals(thread)
      tool_executions = thread.tool_executions.where(status: %w[proposed queued running]).order(created_at: :asc)
      Turbo::StreamsChannel.broadcast_replace_to(
        "assistant_thread_#{thread.id}",
        target: ActionView::RecordIdentifier.dom_id(thread, :tool_executions),
        partial: "assistant/threads/tool_proposals",
        locals: { thread: thread, tool_executions: tool_executions }
      )
    rescue StandardError
      # best-effort only
    end
  end
end
