# frozen_string_literal: true

module AdminSuite
  class DocsController < ApplicationController
    before_action :set_docs_root

    # GET /docs
    # GET /docs?path=relative/path.md
    def index
      @files = grouped_markdown_files
      @selected_path = params[:path].presence

      if @selected_path.present?
        load_doc_content(@selected_path)
      elsif @files.values.flatten.any?
        @selected_path = @files.values.flatten.first
        load_doc_content(@selected_path)
      end
    end

    # GET /docs/*path
    def show
      relative_path = params[:path].to_s
      file_path = resolve_doc_path!(relative_path)

      @files = grouped_markdown_files
      @selected_path = relative_path
      @title = File.basename(file_path, ".md").tr("_", " ").tr("-", " ").titleize
      @raw_markdown = File.read(file_path)

      rendered = markdown_renderer.new(@raw_markdown).render
      @content_html = rendered[:html]
      @toc = rendered[:toc]
      @reading_time = rendered[:reading_time_minutes]

      render :index
    rescue ActiveRecord::RecordNotFound
      redirect_to docs_path, alert: "Doc not found."
    end

    private

    def set_docs_root
      @docs_root = docs_root
    end

    def load_doc_content(relative_path)
      file_path = resolve_doc_path!(relative_path)
      @title = File.basename(file_path, ".md").tr("_", " ").tr("-", " ").titleize
      @raw_markdown = File.read(file_path)

      rendered = markdown_renderer.new(@raw_markdown).render
      @content_html = rendered[:html]
      @toc = rendered[:toc]
      @reading_time = rendered[:reading_time_minutes]
    rescue ActiveRecord::RecordNotFound
      @title = nil
      @content_html = nil
      @toc = []
      @reading_time = nil
    end

    def markdown_renderer
      AdminSuite::MarkdownRenderer
    rescue NameError
      # In development, new engine lib files can be added without a server restart.
      # Make the docs viewer resilient by loading the renderer on demand.
      require "admin_suite/markdown_renderer"
      AdminSuite::MarkdownRenderer
    end

    def grouped_markdown_files
      base = docs_root_realpath
      files = Dir.glob(base.join("**/*.md")).sort.map do |abs|
        abs_path = Pathname.new(abs)
        abs_path.relative_path_from(base).to_s
      end

      groups = files.group_by { |path| group_name_for_path(path) }
      groups.sort_by { |k, _| k.to_s }.to_h
    rescue StandardError
      {}
    end

    def group_name_for_path(relative_path)
      folder = relative_path.to_s.split(File::SEPARATOR).first
      if folder.present? && folder != File.basename(relative_path.to_s)
        return humanize_folder_name(folder)
      end

      "Docs"
    end

    def humanize_folder_name(folder)
      normalized = folder.to_s.tr("_", " ").tr("-", " ").strip
      acronyms = {
        "cicd" => "CICD",
        "ci cd" => "CICD",
        "ai" => "AI",
        "ops" => "Ops",
        "oauth" => "OAuth",
        "ui" => "UI",
        "ux" => "UX",
        "api" => "API"
      }

      key = normalized.downcase
      return acronyms[key] if acronyms.key?(key)

      normalized.titleize
    end

    def docs_root
      value =
        if AdminSuite.config.respond_to?(:docs_path)
          AdminSuite.config.docs_path
        else
          Rails.root.join("docs")
        end
      value = value.call(self) if value.respond_to?(:call)
      value = Rails.root.join("docs") if value.blank?
      Pathname.new(value.to_s)
    end

    def resolve_doc_path!(relative_path)
      raise ActiveRecord::RecordNotFound if relative_path.blank?
      raise ActiveRecord::RecordNotFound if relative_path.include?("..")

      base = docs_root_realpath
      candidate = base.join(relative_path)
      raise ActiveRecord::RecordNotFound unless candidate.extname == ".md"

      real = candidate.realpath
      raise ActiveRecord::RecordNotFound unless real.to_s.start_with?(base.to_s + File::SEPARATOR)

      real.to_s
    rescue Errno::ENOENT, Errno::EACCES
      raise ActiveRecord::RecordNotFound
    end

    def docs_root_realpath
      docs_root.realpath
    rescue Errno::ENOENT
      docs_root
    end
  end
end
