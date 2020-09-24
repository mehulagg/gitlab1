# frozen_string_literal: true

class Projects::MergeRequests::DiffsController < Projects::MergeRequests::ApplicationController
  include DiffHelper
  include RendersNotes

  before_action :commit
  before_action :define_diff_vars
  before_action :define_diff_comment_vars, except: [:diffs_batch, :diffs_metadata]
  before_action :update_diff_discussion_positions!

  around_action :allow_gitaly_ref_name_caching

  def show
    render_diffs
  end

  def diff_for_path
    render_diffs
  end

  def diffs_batch
    diffs = @compare.diffs_in_batch(params[:page], params[:per_page], diff_options: diff_options)
    positions = @merge_request.note_positions_for_paths(diffs.diff_file_paths, current_user)
    environment = @merge_request.environments_for(current_user, latest: true).last

    diffs.unfold_diff_files(positions.unfoldable)
    diffs.write_cache

    options = {
      environment: environment,
      merge_request: @merge_request,
      diff_view: diff_view,
      pagination_data: diffs.pagination_data
    }

    render json: PaginatedDiffSerializer.new(current_user: current_user).represent(diffs, options)
  end

  def diffs_metadata
    diffs = @compare.diffs(diff_options)

    render json: DiffsMetadataSerializer.new(project: @merge_request.project, current_user: current_user)
                   .represent(diffs, additional_attributes)
  end

  private

  def preloadable_mr_relations
    [{ source_project: :namespace }, { target_project: :namespace }]
  end

  # Deprecated: https://gitlab.com/gitlab-org/gitlab/issues/37735
  def render_diffs
    diffs = @compare.diffs(diff_options)
    @environment = @merge_request.environments_for(current_user, latest: true).last

    diffs.unfold_diff_files(note_positions.unfoldable)
    diffs.write_cache

    request = {
      current_user: current_user,
      project: @merge_request.project,
      render: ->(partial, locals) { view_to_html_string(partial, locals) }
    }

    options = additional_attributes.merge(diff_view: Feature.enabled?(:unified_diff_lines, @merge_request.project) ? "inline" : diff_view)

    if @merge_request.project.context_commits_enabled?
      options[:context_commits] = @merge_request.recent_context_commits
    end

    render json: DiffsSerializer.new(request).represent(diffs, options)
  end

  # Deprecated: https://gitlab.com/gitlab-org/gitlab/issues/37735
  def define_diff_vars
    @merge_request_diffs = @merge_request.merge_request_diffs.viewable.order_id_desc
    @compare = commit || find_merge_request_diff_compare
    return render_404 unless @compare
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def commit
    return unless commit_id = params[:commit_id].presence
    return unless @merge_request.all_commits.exists?(sha: commit_id)

    @commit ||= @project.commit(commit_id)
  end
  # rubocop: enable CodeReuse/ActiveRecord

  # rubocop: disable CodeReuse/ActiveRecord
  #
  # Deprecated: https://gitlab.com/gitlab-org/gitlab/issues/37735
  def find_merge_request_diff_compare
    @merge_request_diff =
      if params[:diff_id].present?
        @merge_request.merge_request_diffs.viewable.find_by(id: params[:diff_id])
      else
        @merge_request.merge_request_diff
      end

    return unless @merge_request_diff&.id

    @comparable_diffs = @merge_request_diffs.select { |diff| diff.id < @merge_request_diff.id }

    if @start_sha = params[:start_sha].presence
      @start_version = @comparable_diffs.find { |diff| diff.head_commit_sha == @start_sha }

      unless @start_version
        @start_sha = @merge_request_diff.head_commit_sha
        @start_version = @merge_request_diff
      end
    end

    if Gitlab::Utils.to_boolean(params[:diff_head]) && @merge_request.diffable_merge_ref?
      return CompareService.new(@project, @merge_request.merge_ref_head.sha)
        .execute(@project, @merge_request.target_branch)
    end

    if @start_sha
      @merge_request_diff.compare_with(@start_sha)
    else
      @merge_request_diff
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def additional_attributes
    {
      environment: @environment,
      merge_request: @merge_request,
      merge_request_diff: @merge_request_diff,
      merge_request_diffs: @merge_request_diffs,
      start_version: @start_version,
      start_sha: @start_sha,
      commit: @commit,
      latest_diff: @merge_request_diff&.latest?
    }
  end

  # Deprecated: https://gitlab.com/gitlab-org/gitlab/issues/37735
  def define_diff_comment_vars
    @new_diff_note_attrs = {
      noteable_type: 'MergeRequest',
      noteable_id: @merge_request.id,
      commit_id: @commit&.id
    }

    @diff_notes_disabled = false

    @use_legacy_diff_notes = !@merge_request.has_complete_diff_refs?

    @grouped_diff_discussions = @merge_request.grouped_diff_discussions(@compare.diff_refs)
    @notes = prepare_notes_for_rendering(@grouped_diff_discussions.values.flatten.flat_map(&:notes), @merge_request)
  end

  def note_positions
    @note_positions ||= Gitlab::Diff::PositionCollection.new(renderable_notes.map(&:position))
  end

  def renderable_notes
    define_diff_comment_vars unless @notes

    draft_notes =
      if current_user
        merge_request.draft_notes.authored_by(current_user)
      else
        []
      end

    @notes.concat(draft_notes)
  end

  def update_diff_discussion_positions!
    return unless Feature.enabled?(:merge_ref_head_comments, @merge_request.target_project, default_enabled: true)
    return unless Feature.enabled?(:merge_red_head_comments_position_on_demand, @merge_request.target_project, default_enabled: true)
    return if @merge_request.has_any_diff_note_positions?

    Discussions::CaptureDiffNotePositionsService.new(@merge_request).execute
  end
end
