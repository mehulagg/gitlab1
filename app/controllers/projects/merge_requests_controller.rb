class Projects::MergeRequestsController < Projects::ApplicationController
  include ToggleSubscriptionAction
  include DiffForPath
  include DiffHelper
  include IssuableActions
  include RendersNotes
  include ToggleAwardEmoji
  include IssuableCollections

  before_action :module_enabled
  before_action :merge_request, only: [
    :edit, :update, :show, :diffs, :commits, :conflicts, :conflict_for_path, :pipelines, :merge,
    :pipeline_status, :ci_environments_status, :toggle_subscription, :cancel_merge_when_pipeline_succeeds,
    :remove_wip, :resolve_conflicts, :assign_related_issues, :commit_change_content,
    # EE
    :approve, :approvals, :unapprove, :rebase
  ]
  before_action :validates_merge_request, only: [:show, :diffs, :commits, :pipelines]
  before_action :define_show_vars, only: [:diffs, :commits, :conflicts, :conflict_for_path, :builds, :pipelines]
  before_action :define_commit_vars, only: [:diffs]
  before_action :ensure_ref_fetched, only: [:show, :diffs, :commits, :builds, :conflicts, :conflict_for_path, :pipelines]
  before_action :close_merge_request_without_source_project, only: [:show, :diffs, :commits, :builds, :pipelines]
  before_action :check_if_can_be_merged, only: :show
  before_action :apply_diff_view_cookie!, only: [:new_diffs]
  before_action :build_merge_request, only: [:new, :new_diffs]
  before_action :set_suggested_approvers, only: [:new, :new_diffs, :edit]

  # Allow read any merge_request
  before_action :authorize_read_merge_request!

  # Allow write(create) merge_request
  before_action :authorize_create_merge_request!, only: [:new, :create]

  # Allow modify merge_request
  before_action :authorize_update_merge_request!, only: [:close, :edit, :update, :remove_wip, :sort]

  before_action :authenticate_user!, only: [:assign_related_issues]

  before_action :authorize_can_resolve_conflicts!, only: [:conflicts, :conflict_for_path, :resolve_conflicts]

  def index
    @collection_type    = "MergeRequest"
    @merge_requests     = merge_requests_collection
    @merge_requests     = @merge_requests.page(params[:page])
    @merge_requests     = @merge_requests.preload(merge_request_diff: :merge_request)
    @issuable_meta_data = issuable_meta_data(@merge_requests, @collection_type)

    if @merge_requests.out_of_range? && @merge_requests.total_pages != 0
      return redirect_to url_for(params.merge(page: @merge_requests.total_pages, only_path: true))
    end

    if params[:label_name].present?
      labels_params = { project_id: @project.id, title: params[:label_name] }
      @labels = LabelsFinder.new(current_user, labels_params).execute
    end

    @users = []
    if params[:assignee_id].present?
      assignee = User.find_by_id(params[:assignee_id])
      @users.push(assignee) if assignee
    end

    if params[:author_id].present?
      author = User.find_by_id(params[:author_id])
      @users.push(author) if author
    end

    respond_to do |format|
      format.html
      format.json do
        render json: {
          html: view_to_html_string("projects/merge_requests/_merge_requests"),
          labels: @labels.as_json(methods: :text_color)
        }
      end
    end
  end

  def show
    respond_to do |format|
      format.html do
        define_discussion_vars
        define_show_vars
      end

      format.json do
        Gitlab::PollingInterval.set_header(response, interval: 10_000)

        render json: serializer.represent(@merge_request, basic: params[:basic])
      end

      format.patch  do
        return render_404 unless @merge_request.diff_refs

        send_git_patch @project.repository, @merge_request.diff_refs
      end

      format.diff do
        return render_404 unless @merge_request.diff_refs

        send_git_diff @project.repository, @merge_request.diff_refs
      end
    end
  end

  def diffs
    apply_diff_view_cookie!

    respond_to do |format|
      format.html { define_discussion_vars }
      format.json do
        define_diff_vars
        define_diff_comment_vars

        @environment = @merge_request.environments_for(current_user).last

        render json: { html: view_to_html_string("projects/merge_requests/show/_diffs") }
      end
    end
  end

  # With an ID param, loads the MR at that ID. Otherwise, accepts the same params as #new
  # and uses that (unsaved) MR.
  #
  def diff_for_path
    if params[:id]
      merge_request
      define_diff_vars
      define_diff_comment_vars
    else
      build_merge_request
      @compare = @merge_request
      @diffs = @compare.diffs(diff_options)
      @diff_notes_disabled = true
    end

    define_commit_vars

    render_diff_for_path(@diffs)
  end

  def commits
    respond_to do |format|
      format.html do
        define_discussion_vars

        render 'show'
      end
      format.json do
        # Get commits from repository
        # or from cache if already merged
        @commits = @merge_request.commits
        @note_counts = Note.where(commit_id: @commits.map(&:id)).
          group(:commit_id).count

        render json: { html: view_to_html_string('projects/merge_requests/show/_commits') }
      end
    end
  end

  def conflicts
    respond_to do |format|
      format.html { define_discussion_vars }

      format.json do
        if @conflicts_list.can_be_resolved_in_ui?
          render json: @conflicts_list
        elsif @merge_request.can_be_merged?
          render json: {
            message: 'The merge conflicts for this merge request have already been resolved. Please return to the merge request.',
            type: 'error'
          }
        else
          render json: {
            message: 'The merge conflicts for this merge request cannot be resolved through GitLab. Please try to resolve them locally.',
            type: 'error'
          }
        end
      end
    end
  end

  def conflict_for_path
    return render_404 unless @conflicts_list.can_be_resolved_in_ui?

    file = @conflicts_list.file_for_path(params[:old_path], params[:new_path])

    return render_404 unless file

    render json: file, full_content: true
  end

  def resolve_conflicts
    return render_404 unless @conflicts_list.can_be_resolved_in_ui?

    if @merge_request.can_be_merged?
      render status: :bad_request, json: { message: 'The merge conflicts for this merge request have already been resolved.' }
      return
    end

    begin
      MergeRequests::Conflicts::ResolveService.
        new(merge_request).
        execute(current_user, params)

      flash[:notice] = 'All merge conflicts were resolved. The merge request can now be merged.'

      render json: { redirect_to: namespace_project_merge_request_url(@project.namespace, @project, @merge_request, resolved_conflicts: true) }
    rescue Gitlab::Conflict::ResolutionError => e
      render status: :bad_request, json: { message: e.message }
    end
  end

  def pipelines
    @pipelines = @merge_request.all_pipelines

    respond_to do |format|
      format.html do
        define_discussion_vars

        render 'show'
      end

      format.json do
        Gitlab::PollingInterval.set_header(response, interval: 10_000)

        render json: PipelineSerializer
          .new(project: @project, current_user: @current_user)
          .represent(@pipelines)
      end
    end
  end

  def new
    respond_to do |format|
      format.html { define_new_vars }
      format.json do
        define_pipelines_vars

        Gitlab::PollingInterval.set_header(response, interval: 10_000)

        render json: {
          pipelines: PipelineSerializer
          .new(project: @project, current_user: @current_user)
          .represent(@pipelines)
        }
      end
    end
  end

  def new_diffs
    respond_to do |format|
      format.html do
        define_new_vars
        @show_changes_tab = true
        render "new"
      end
      format.json do
        @diffs = if @merge_request.can_be_created
                   @merge_request.diffs(diff_options)
                 else
                   []
                 end
        @diff_notes_disabled = true

        @environment = @merge_request.environments_for(current_user).last

        render json: { html: view_to_html_string('projects/merge_requests/_new_diffs', diffs: @diffs, environment: @environment) }
      end
    end
  end

  def create
    @target_branches ||= []
    create_params = clamp_approvals_before_merge(merge_request_params)

    @merge_request = MergeRequests::CreateService.new(project, current_user, create_params).execute

    if @merge_request.valid?
      redirect_to(merge_request_path(@merge_request))
    else
      @source_project = @merge_request.source_project
      @target_project = @merge_request.target_project
      set_suggested_approvers

      render action: "new"
    end
  end

  def edit
    @source_project = @merge_request.source_project
    @target_project = @merge_request.target_project
    @target_branches = @merge_request.target_project.repository.branch_names
  end

  def update
    update_params = clamp_approvals_before_merge(merge_request_params)

    @merge_request = MergeRequests::UpdateService.new(project, current_user, update_params).execute(@merge_request)

    respond_to do |format|
      format.html do
        if @merge_request.valid?
          redirect_to([@merge_request.target_project.namespace.becomes(Namespace), @merge_request.target_project, @merge_request])
        else
          set_suggested_approvers

          render :edit
        end
      end

      format.json do
        render json: @merge_request.to_json(include: { milestone: {}, assignee: { only: [:name, :username], methods: [:avatar_url] }, labels: { methods: :text_color } }, methods: [:task_status, :task_status_short])
      end
    end
  rescue ActiveRecord::StaleObjectError
    render_conflict_response
  end

  def remove_wip
    @merge_request = MergeRequests::UpdateService
      .new(project, current_user, wip_event: 'unwip')
      .execute(@merge_request)

    render json: serializer.represent(@merge_request)
  end

  def commit_change_content
    render partial: 'projects/merge_requests/widget/commit_change_content', layout: false
  end

  def cancel_merge_when_pipeline_succeeds
    unless @merge_request.can_cancel_merge_when_pipeline_succeeds?(current_user)
      return access_denied!
    end

    MergeRequests::MergeWhenPipelineSucceedsService
      .new(@project, current_user)
      .cancel(@merge_request)

    render json: serializer.represent(@merge_request)
  end

  def rebase
    return access_denied! unless @merge_request.can_be_merged_by?(current_user)
    return render_404 unless @merge_request.approved?

    RebaseWorker.perform_async(@merge_request.id, current_user.id)

    render nothing: true, status: 200
  end

  def merge
    return access_denied! unless @merge_request.can_be_merged_by?(current_user)
    return render_404 unless @merge_request.approved?

    status = merge!

    if @merge_request.merge_error
      render json: { status: status, merge_error: @merge_request.merge_error }
    else
      render json: { status: status }
    end
  end

  def branch_from
    # This is always source
    @source_project = @merge_request.nil? ? @project : @merge_request.source_project

    if params[:ref].present?
      @ref = params[:ref]
      @commit = @repository.commit("refs/heads/#{@ref}")
    end

    render layout: false
  end

  def branch_to
    @target_project = selected_target_project

    if params[:ref].present?
      @ref = params[:ref]
      @commit = @target_project.commit("refs/heads/#{@ref}")
    end

    render layout: false
  end

  def update_branches
    @target_project = selected_target_project
    @target_branches = @target_project.repository.branch_names

    render layout: false
  end

  def assign_related_issues
    result = MergeRequests::AssignIssuesService.new(project, current_user, merge_request: @merge_request).execute

    respond_to do |format|
      format.html do
        case result[:count]
        when 0
          flash[:error] = "Failed to assign you issues related to the merge request"
        when 1
          flash[:notice] = "1 issue has been assigned to you"
        else
          flash[:notice] = "#{result[:count]} issues have been assigned to you"
        end

        redirect_to(merge_request_path(@merge_request))
      end
    end
  end

  def pipeline_status
    render json: PipelineSerializer
      .new(project: @project, current_user: @current_user)
      .represent_status(@merge_request.head_pipeline)
  end

  def ci_environments_status
    environments =
      begin
        @merge_request.environments_for(current_user).map do |environment|
          project = environment.project
          deployment = environment.first_deployment_for(@merge_request.diff_head_commit)

          stop_url =
            if environment.stop_action? && can?(current_user, :create_deployment, environment)
              stop_namespace_project_environment_path(project.namespace, project, environment)
            end

          metrics_url =
            if can?(current_user, :read_environment, environment) && environment.has_metrics?
              metrics_namespace_project_environment_path(environment.project.namespace,
                                                         environment.project,
                                                         environment,
                                                         deployment)
            end

          {
            id: environment.id,
            name: environment.name,
            url: namespace_project_environment_path(project.namespace, project, environment),
            metrics_url: metrics_url,
            stop_url: stop_url,
            external_url: environment.external_url,
            external_url_formatted: environment.formatted_external_url,
            deployed_at: deployment.try(:created_at),
            deployed_at_formatted: deployment.try(:formatted_deployment_time)
          }
        end.compact
      end

    render json: environments
  end

  def approve
    unless @merge_request.can_approve?(current_user)
      return render_404
    end

    ::MergeRequests::ApprovalService
      .new(project, current_user)
      .execute(@merge_request)

    render_approvals_json
  end

  def approvals
    render_approvals_json
  end

  def unapprove
    if @merge_request.has_approved?(current_user)
      ::MergeRequests::RemoveApprovalService
        .new(project, current_user)
        .execute(@merge_request)
    end

    render_approvals_json
  end

  protected

  def render_approvals_json
    respond_to do |format|
      format.json do
        entity = API::Entities::MergeRequestApprovals.new(@merge_request, current_user: current_user)
        render json: entity
      end
    end
  end

  def selected_target_project
    if @project.id.to_s == params[:target_project_id] || @project.forked_project_link.nil?
      @project
    else
      @project.forked_project_link.forked_from_project
    end
  end

  def merge_request
    @issuable = @merge_request ||= @project.merge_requests.find_by!(iid: params[:id])
  end
  alias_method :subscribable_resource, :merge_request
  alias_method :issuable, :merge_request
  alias_method :awardable, :merge_request

  def authorize_update_merge_request!
    return render_404 unless can?(current_user, :update_merge_request, @merge_request)
  end

  def authorize_admin_merge_request!
    return render_404 unless can?(current_user, :admin_merge_request, @merge_request)
  end

  def authorize_can_resolve_conflicts!
    @conflicts_list = MergeRequests::Conflicts::ListService.new(@merge_request)

    return render_404 unless @conflicts_list.can_be_resolved_by?(current_user)
  end

  def module_enabled
    return render_404 unless @project.feature_available?(:merge_requests, current_user)
  end

  def validates_merge_request
    # Show git not found page
    # if there is no saved commits between source & target branch
    if @merge_request.has_no_commits?
      # and if target branch doesn't exist
      return invalid_mr unless @merge_request.target_branch_exists?
    end
  end

  def define_show_vars
    @noteable = @merge_request
    @commits_count = @merge_request.commits_count

    if @merge_request.locked_long_ago?
      @merge_request.unlock_mr
      @merge_request.close
    end

    labels
    define_pipelines_vars
  end

  # Discussion tab data is rendered on html responses of actions
  # :show, :diff, :commits, :builds. but not when request the data through AJAX
  def define_discussion_vars
    # Build a note object for comment form
    @note = @project.notes.new(noteable: @merge_request)

    @discussions = @merge_request.discussions
    @notes = prepare_notes_for_rendering(@discussions.flat_map(&:notes))
  end

  def define_commit_vars
    @commit = @merge_request.diff_head_commit
    @base_commit = @merge_request.diff_base_commit || @merge_request.likely_diff_base_commit
  end

  def define_diff_vars
    @merge_request_diff =
      if params[:diff_id]
        @merge_request.merge_request_diffs.viewable.find(params[:diff_id])
      else
        @merge_request.merge_request_diff
      end

    @merge_request_diffs = @merge_request.merge_request_diffs.viewable.select_without_diff
    @comparable_diffs = @merge_request_diffs.select { |diff| diff.id < @merge_request_diff.id }

    if params[:start_sha].present?
      @start_sha = params[:start_sha]
      @start_version = @comparable_diffs.find { |diff| diff.head_commit_sha == @start_sha }

      unless @start_version
        @start_sha = @merge_request_diff.head_commit_sha
        @start_version = @merge_request_diff
      end
    end

    @compare =
      if @start_sha
        @merge_request_diff.compare_with(@start_sha)
      else
        @merge_request_diff
      end

    @diffs = @compare.diffs(diff_options)
  end

  def define_diff_comment_vars
    @new_diff_note_attrs = {
      noteable_type: 'MergeRequest',
      noteable_id: @merge_request.id
    }

    @diff_notes_disabled = false

    @use_legacy_diff_notes = !@merge_request.has_complete_diff_refs?

    @grouped_diff_discussions = @merge_request.grouped_diff_discussions(@compare.diff_refs)
    @notes = prepare_notes_for_rendering(@grouped_diff_discussions.values.flatten.flat_map(&:notes))
  end

  def define_pipelines_vars
    @pipelines = @merge_request.all_pipelines
    @pipeline = @merge_request.head_pipeline
    @statuses_count = @pipeline.present? ? @pipeline.statuses.relevant.count : 0
  end

  def define_new_vars
    @noteable = @merge_request

    @target_branches = if @merge_request.target_project
                         @merge_request.target_project.repository.branch_names
                       else
                         []
                       end

    @target_project = merge_request.target_project
    @source_project = merge_request.source_project
    @commits = @merge_request.compare_commits.reverse
    @commit = @merge_request.diff_head_commit
    @base_commit = @merge_request.diff_base_commit

    @note_counts = Note.where(commit_id: @commits.map(&:id)).
      group(:commit_id).count

    @labels = LabelsFinder.new(current_user, project_id: @project.id).execute

    @show_changes_tab = params[:show_changes].present?

    define_pipelines_vars
  end

  def invalid_mr
    # Render special view for MR with removed target branch
    render 'invalid'
  end

  def set_suggested_approvers
    if @merge_request.requires_approve?
      @suggested_approvers = Gitlab::AuthorityAnalyzer.new(
        @merge_request,
        @merge_request.author || current_user
      ).calculate(@merge_request.approvals_required)
    end
  end

  def merge_request_params
    params.require(:merge_request)
      .permit(merge_request_params_ce << merge_request_params_ee)
  end

  def merge_request_params_ce
    [
      :assignee_id,
      :description,
      :force_remove_source_branch,
      :lock_version,
      :milestone_id,
      :source_branch,
      :source_project_id,
      :state_event,
      :target_branch,
      :target_project_id,
      :task_num,
      :title,

      label_ids: []
    ]
  end

  def merge_request_params_ee
    %i[
      approvals_before_merge
      approver_group_ids
      approver_ids
      squash
    ]
  end

  # If the number of approvals is not greater than the project default, set to
  # nil, so that we fall back to the project default. If it's not set, we can
  # let the normal update logic handle this.
  def clamp_approvals_before_merge(mr_params)
    return mr_params unless mr_params[:approvals_before_merge]

    target_project = @project.forked_from_project if @project.id.to_s != mr_params[:target_project_id]
    target_project ||= @project

    if mr_params[:approvals_before_merge].to_i <= target_project.approvals_before_merge
      mr_params[:approvals_before_merge] = nil
    end

    mr_params
  end

  def merge_params
    params.permit(:should_remove_source_branch, :commit_message, :squash)
  end

  # Make sure merge requests created before 8.0
  # have head file in refs/merge-requests/
  def ensure_ref_fetched
    @merge_request.ensure_ref_fetched
  end

  def merge_when_pipeline_succeeds_active?
    params[:merge_when_pipeline_succeeds].present? &&
      @merge_request.head_pipeline && @merge_request.head_pipeline.active?
  end

  def build_merge_request
    params[:merge_request] ||= ActionController::Parameters.new(source_project: @project)
    @merge_request = MergeRequests::BuildService.new(project, current_user, merge_request_params.merge(diff_options: diff_options)).execute
  end

  def close_merge_request_without_source_project
    if !@merge_request.source_project && @merge_request.open?
      @merge_request.close
    end
  end

  private

  def check_if_can_be_merged
    @merge_request.check_if_can_be_merged
  end

  def merge!
    # Disable the CI check if merge_when_pipeline_succeeds is enabled since we have
    # to wait until CI completes to know
    unless @merge_request.mergeable?(skip_ci_check: merge_when_pipeline_succeeds_active?)
      return :failed
    end

    merge_request_service = MergeRequests::MergeService.new(@project, current_user, merge_params)

    unless merge_request_service.hooks_validation_pass?(@merge_request)
      return :hook_validation_error
    end

    return :sha_mismatch if params[:sha] != @merge_request.diff_head_sha

    @merge_request.update(merge_error: nil, squash: merge_params[:squash])

    if params[:merge_when_pipeline_succeeds].present?
      return :failed unless @merge_request.head_pipeline

      if @merge_request.head_pipeline.active?
        MergeRequests::MergeWhenPipelineSucceedsService
          .new(@project, current_user, merge_params)
          .execute(@merge_request)

        :merge_when_pipeline_succeeds
      elsif @merge_request.head_pipeline.success?
        # This can be triggered when a user clicks the auto merge button while
        # the tests finish at about the same time
        MergeWorker.perform_async(@merge_request.id, current_user.id, params)

        :success
      else
        :failed
      end
    else
      MergeWorker.perform_async(@merge_request.id, current_user.id, params)

      :success
    end
  end

  def serializer
    MergeRequestSerializer.new(current_user: current_user, project: merge_request.project)
  end
end
