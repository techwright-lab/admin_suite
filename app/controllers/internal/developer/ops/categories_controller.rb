# frozen_string_literal: true

module Internal
  module Developer
    module Ops
      # Categories controller for the Ops Portal
      class CategoriesController < Internal::Developer::ResourcesController
        def disable
          @resource.update(disabled: true) if @resource.respond_to?(:disabled=)
          redirect_to resource_url(@resource), notice: "Category disabled."
        end

        def enable
          @resource.update(disabled: false) if @resource.respond_to?(:disabled=)
          redirect_to resource_url(@resource), notice: "Category enabled."
        end

        def merge
          @merge_candidates = resource_class.where.not(id: @resource.id).order(:name).limit(100)
        end

        def merge_into
          target = resource_class.find(params[:target_id])

          result = Category.merge_categories(@resource, target)

          if result[:success]
            redirect_to resource_url(target), notice: "Categories merged successfully. #{result[:message]}"
          else
            redirect_to merge_internal_developer_ops_category_path(@resource), alert: result[:error]
          end
        rescue => e
          Rails.logger.error("Category merge failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
          redirect_to merge_internal_developer_ops_category_path(@resource), alert: "Merge failed: #{e.message}"
        end

        private

        def current_portal
          :ops
        end

        def resource_config
          Admin::Resources::CategoryResource
        end
      end
    end
  end
end

