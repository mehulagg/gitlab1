# frozen_string_literal: true

class MergeRequestWidgetEntity < Grape::Entity
  include RequestAwareEntity

  expose :id
  expose :iid

  expose :source_project_full_path do |merge_request|
    merge_request.source_project&.full_path
  end

  expose :target_project_full_path do |merge_request|
    merge_request.project&.full_path
  end

  expose :email_patches_path do |merge_request|
    project_merge_request_path(merge_request.project, merge_request, format: :patch)
  end

  expose :plain_diff_path do |merge_request|
    project_merge_request_path(merge_request.project, merge_request, format: :diff)
  end

  expose :merge_request_basic_path do |merge_request|
    project_merge_request_path(merge_request.target_project, merge_request, serializer: :basic, format: :json)
  end

  expose :merge_request_widget_path do |merge_request|
    widget_project_json_merge_request_path(merge_request.target_project, merge_request, format: :json)
  end

  expose :merge_request_cached_widget_path do |merge_request|
    cached_widget_project_json_merge_request_path(merge_request.target_project, merge_request, format: :json)
  end

  expose :commit_change_content_path do |merge_request|
    commit_change_content_project_merge_request_path(merge_request.project, merge_request)
  end

  expose :conflicts_docs_path do |merge_request|
    help_page_path('user/project/merge_requests/resolve_conflicts.md')
  end

  expose :merge_request_pipelines_docs_path do |merge_request|
    help_page_path('ci/merge_request_pipelines/index.md')
  end

  expose :ci_environments_status_path do |merge_request|
    ci_environments_status_project_merge_request_path(merge_request.project, merge_request)
  end

  expose :merge_request_add_ci_config_path, if: ->(mr, _) { can_add_ci_config_path?(mr) } do |merge_request|
    project_new_blob_path(
      merge_request.source_project,
      merge_request.source_branch,
      file_name: '.gitlab-ci.yml',
      commit_message: s_("CommitMessage|Add %{file_name}") % { file_name: Gitlab::FileDetector::PATTERNS[:gitlab_ci] },
      suggest_gitlab_ci_yml: true
    )
  end

  expose :human_access do |merge_request|
    merge_request.project.team.human_max_access(current_user&.id)
  end

  # Rendering and redacting Markdown can be expensive. These links are
  # just nice to have in the merge request widget, so only
  # include them if they are explicitly requested on first load.
  expose :issues_links, if: -> (_, opts) { opts[:issues_links] } do
    expose :assign_to_closing do |merge_request|
      presenter(merge_request).assign_to_closing_issues_link
    end

    expose :closing do |merge_request|
      presenter(merge_request).closing_issues_links
    end

    expose :mentioned_but_not_closing do |merge_request|
      presenter(merge_request).mentioned_issues_links
    end
  end

  private

  delegate :current_user, to: :request

  def presenter(merge_request)
    @presenters ||= {}
    @presenters[merge_request] ||= MergeRequestPresenter.new(merge_request, current_user: current_user) # rubocop: disable CodeReuse/Presenter
  end

  def can_add_ci_config_path?(merge_request)
    merge_request.source_project&.uses_default_ci_config? &&
      merge_request.all_pipelines.none? &&
      merge_request.commits_count.positive? &&
      can?(current_user, :read_build, merge_request.source_project) &&
      can?(current_user, :create_pipeline, merge_request.source_project)
  end
end

MergeRequestWidgetEntity.prepend_if_ee('EE::MergeRequestWidgetEntity')
