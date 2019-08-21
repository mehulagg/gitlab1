# frozen_string_literal: true

class DiscussionEntity < Grape::Entity
  include RequestAwareEntity
  include ResolveableNoteEntity
  include NotesHelper

  expose :id, :reply_id
  expose :position, if: -> (d, _) { d.diff_discussion? && !d.legacy_diff_discussion? }
  expose :original_position, if: -> (d, _) { d.diff_discussion? && !d.legacy_diff_discussion? }
  expose :line_code, if: -> (d, _) { d.diff_discussion? }
  expose :expanded?, as: :expanded
  expose :active?, as: :active, if: -> (d, _) { d.diff_discussion? }
  expose :project_id

  expose :notes do |discussion, opts|
    request.note_entity.represent(discussion.notes, opts)
  end

  expose :discussion_path do |discussion|
    discussion_path(discussion)
  end

  expose :individual_note?, as: :individual_note
  expose :resolvable do |discussion|
    discussion.resolvable?
  end

  expose :resolve_path, if: -> (d, _) { d.resolvable? } do |discussion|
    resolve_project_merge_request_discussion_path(discussion.project, discussion.noteable, discussion.id)
  end
  expose :resolve_with_issue_path, if: -> (d, _) { d.resolvable? && d.for_merge_request? } do |discussion|
    new_project_issue_path(discussion.project, merge_request_to_resolve_discussions_of: discussion.noteable.iid, discussion_to_resolve: discussion.id)
  end

  expose :diff_file, if: -> (d, options) { d.diff_discussion? } do |discussion, options|
    options = options.merge(design: discussion.noteable) if discussion.for_design?

    DiscussionDiffFileEntity.represent(discussion.diff_file, options)
  end

  expose :diff_discussion?, as: :diff_discussion

  expose :truncated_diff_lines_path, if: -> (d, _) { !d.expanded? && d.for_merge_request? && !render_truncated_diff_lines? } do |discussion|
    project_merge_request_discussion_path(discussion.project, discussion.noteable, discussion)
  end

  expose :truncated_diff_lines, using: DiffLineEntity, if: -> (d, _) { d.diff_discussion? && d.on_text? && (d.expanded? || render_truncated_diff_lines?) }

  expose :for_commit?, as: :for_commit
  expose :for_design?, as: :for_design
  expose :commit_id

  private

  def render_truncated_diff_lines?
    options[:render_truncated_diff_lines]
  end

  def current_user
    request.current_user
  end
end
