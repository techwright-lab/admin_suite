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

        groups = files.group_by { |path| group_name_for_path(path) }

        # Sort groups with preferred order, then alphabetically
        preferred_order = [
          "Overview",
          "CICD",
          "Developer Portal",
          "Billing",
          "Google Integration",
          "Testing",
          "Assistant",
          "Admin UI",
          "Features",
          "Other"
        ]

        groups.sort_by { |k, _| [ preferred_order.index(k) || 999, k ] }.to_h
      end

      def group_name_for_path(relative_path)
        # Folder-based grouping: docs/<folder>/* -> "<Folder>" section
        folder = relative_path.to_s.split(File::SEPARATOR).first
        if folder.present? && folder != File.basename(relative_path.to_s)
          return humanize_folder_name(folder)
        end

        # Root files (docs/*.md): keep legacy prefix grouping for backward compatibility
        legacy_group_for_basename(File.basename(relative_path.to_s, ".md"))
      end

      def legacy_group_for_basename(name)
        if name == "README"
          "Overview"
        elsif name.start_with?("ASSISTANT_")
          "Assistant"
        elsif name.start_with?("ADMIN_")
          "Admin UI"
        elsif name.start_with?("GOOGLE_")
          "Google Integration"
        elsif name.start_with?("TEST")
          "Testing"
        elsif name.start_with?("DEVELOPER_PORTAL_")
          "Developer Portal"
        elsif name.include?("BILLING") || name.include?("SUBSCRIPTION")
          "Billing"
        else
          "Other"
        end
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
