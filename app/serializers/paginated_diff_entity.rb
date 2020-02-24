# frozen_string_literal: true

# Serializes diffs with pagination data.
#
# Avoid adding more keys to this serializer as processing the
# diff file serialization is not cheap.
#
class PaginatedDiffEntity < Grape::Entity
  include RequestAwareEntity

  expose :diff_files do |diffs, options|
    submodule_links = Gitlab::SubmoduleLinks.new(merge_request.project.repository)
    DiffFileEntity.represent(diffs.diff_files, options.merge(submodule_links: submodule_links))
  end

  expose :pagination do
    expose :current_page
    expose :next_page
    expose :total_pages
    expose :next_page_href do |diffs|
      next unless next_page

      project = merge_request.target_project

      diffs_batch_namespace_project_json_merge_request_path(
        namespace_id: project.namespace.to_param,
        project_id: project.to_param,
        id: merge_request.iid,
        page: next_page,
        format: :json
      )
    end
  end

  expose :head_version_path do |diffs, options|
    project = merge_request.target_project

    next unless project && merge_request.diffable_merge_ref?

    diffs_project_merge_request_path(project, merge_request, diff_head: true)
  end

  private

  %i[current_page next_page total_pages].each do |method|
    define_method method do
      pagination_data[method]
    end
  end

  def pagination_data
    options.fetch(:pagination_data, {})
  end

  def merge_request
    options[:merge_request]
  end
end
