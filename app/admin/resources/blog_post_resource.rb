# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Blog Post admin management
    #
    # Provides full CRUD operations for blog posts with markdown preview.
    class BlogPostResource < Admin::Base::Resource
      model BlogPost
      portal :ops
      section :content

      index do
        searchable :title, :slug
        sortable :title, :created_at, :published_at, default: :created_at
        paginate 30

        stats do
          stat :total, -> { BlogPost.count }
          stat :published, -> { BlogPost.where(status: "published").count }, color: :green
          stat :draft, -> { BlogPost.where(status: "draft").count }, color: :slate
        end

        columns do
          column :title
          column :slug
          column :status
          column :author_name, header: "Author"
          column :published_at, ->(bp) { bp.published_at&.strftime("%b %d, %Y") || "—" }
        end

        filters do
          filter :status, type: :select, options: [
            ["All Statuses", ""],
            ["Published", "published"],
            ["Draft", "draft"]
          ]
          filter :sort, type: :select, options: [
            ["Recently Added", "recent"],
            ["Title (A-Z)", "title"],
            ["Published Date", "published_at"]
          ]
        end
      end

      form do
        section "Post Details" do
          field :title, required: true
          field :slug, help: "URL-friendly identifier (auto-generated if blank)"
          field :author_name, label: "Author"
          field :excerpt, type: :textarea, rows: 2, help: "Brief summary for listings"
        end

        section "Cover Image" do
          field :cover_image, type: :image, 
                accept: "image/jpeg,image/png,image/webp",
                help: "Recommended size: 1200x630 pixels for best social media preview"
        end

        section "Content" do
          field :body, type: :markdown, rows: 20, help: "Supports Markdown formatting"
        end

        section "Publishing" do
          row cols: 2 do
            field :status, type: :select, collection: [
              ["Draft", "draft"],
              ["Published", "published"]
            ]
            field :published_at, type: :datetime
          end
          field :tag_list, type: :tags, label: "Tags",
                collection: -> { ActsAsTaggableOn::Tag.most_used(20).pluck(:name) },
                creatable: true,
                placeholder: "Add tags...",
                help: "Select existing tags or create new ones"
        end
      end

      show do
        sidebar do
          panel :meta, title: "Post Info", fields: [:slug, :status, :author_name]
          panel :dates, title: "Dates", fields: [:published_at, :created_at, :updated_at]
        end
        
        main do
          panel :excerpt, title: "Excerpt", fields: [:excerpt]
          panel :content, title: "Content", fields: [:body]
          panel :tags, title: "Tags", fields: [:tag_list]
        end
      end

      actions do
        action :publish, method: :post, if: ->(bp) { bp.status == "draft" }
        action :unpublish, method: :post, if: ->(bp) { bp.status == "published" }
      end

      exportable :json
    end
  end
end

