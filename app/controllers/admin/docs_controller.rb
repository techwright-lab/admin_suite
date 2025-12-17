# frozen_string_literal: true

module Admin
  # Admin-only markdown docs viewer for files under Rails.root/docs.
  class DocsController < BaseController
    DOCS_ROOT = Rails.root.join("docs").freeze

    # GET /admin/docs
    def index
      @files = markdown_files
    end

    # GET /admin/docs/*path
    def show
      relative_path = params[:path].to_s
      file_path = resolve_doc_path!(relative_path)

      @relative_path = relative_path
      @title = File.basename(file_path, ".md").tr("_", " ").tr("-", " ").titleize
      @raw_markdown = File.read(file_path)

      rendered = MarkdownRenderer.new(@raw_markdown).render
      @content_html = rendered[:html]
      @toc = rendered[:toc]
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_docs_path, alert: "Doc not found."
    end

    private

    def markdown_files
      base = docs_root_realpath
      Dir.glob(base.join("**/*.md")).sort.map do |abs|
        abs_path = Pathname.new(abs)
        abs_path.relative_path_from(base).to_s
      end
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
      DOCS_ROOT.realpath
    rescue Errno::ENOENT
      DOCS_ROOT
    end
  end
end


