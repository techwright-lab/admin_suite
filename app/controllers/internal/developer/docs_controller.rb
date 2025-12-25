# frozen_string_literal: true

module Internal
  module Developer
    # Developer portal documentation viewer
    #
    # Provides a two-panel layout for browsing docs from Rails.root/docs
    class DocsController < BaseController
      DOCS_ROOT = Rails.root.join("docs").freeze

      # GET /internal/developer/docs
      # GET /internal/developer/docs?path=ASSISTANT_OVERVIEW.md
      def index
        @files = grouped_markdown_files
        @selected_path = params[:path].presence

        if @selected_path.present?
          load_doc_content(@selected_path)
        elsif @files.values.flatten.any?
          # Auto-select the first doc if none specified
          @selected_path = @files.values.flatten.first
          load_doc_content(@selected_path)
        end
      end

      # GET /internal/developer/docs/:path (for direct linking)
      def show
        relative_path = params[:path].to_s
        file_path = resolve_doc_path!(relative_path)

        @files = grouped_markdown_files
        @selected_path = relative_path
        @title = File.basename(file_path, ".md").tr("_", " ").tr("-", " ").titleize
        @raw_markdown = File.read(file_path)

        rendered = MarkdownRenderer.new(@raw_markdown).render
        @content_html = rendered[:html]
        @toc = rendered[:toc]
        @reading_time = rendered[:reading_time_minutes]

        render :index
      rescue ActiveRecord::RecordNotFound
        redirect_to internal_developer_docs_path, alert: "Doc not found."
      end

      private

      def load_doc_content(relative_path)
        file_path = resolve_doc_path!(relative_path)
        @title = File.basename(file_path, ".md").tr("_", " ").tr("-", " ").titleize
        @raw_markdown = File.read(file_path)

        rendered = MarkdownRenderer.new(@raw_markdown).render
        @content_html = rendered[:html]
        @toc = rendered[:toc]
        @reading_time = rendered[:reading_time_minutes]
      rescue ActiveRecord::RecordNotFound
        @title = nil
        @content_html = nil
        @toc = []
        @reading_time = nil
      end

      def grouped_markdown_files
        base = docs_root_realpath
        files = Dir.glob(base.join("**/*.md")).sort.map do |abs|
          abs_path = Pathname.new(abs)
          abs_path.relative_path_from(base).to_s
        end

        # Group files by prefix (ASSISTANT_, ADMIN_, etc.)
        groups = files.group_by do |path|
          name = File.basename(path, ".md")
          if name.start_with?("ASSISTANT_")
            "Assistant"
          elsif name.start_with?("ADMIN_")
            "Admin UI"
          elsif name.start_with?("GOOGLE_")
            "Google Integration"
          elsif name.start_with?("TEST")
            "Testing"
          elsif name == "README"
            "Overview"
          else
            "Other"
          end
        end

        # Sort groups with preferred order
        preferred_order = %w[Overview Assistant Admin\ UI Google\ Integration Testing Other]
        groups.sort_by { |k, _| preferred_order.index(k) || 999 }.to_h
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
end

