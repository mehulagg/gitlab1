# frozen_string_literal: true

module Notes
  class BuildService < ::BaseService
    def execute
      should_resolve = false
      in_reply_to_discussion_id = params.delete(:in_reply_to_discussion_id)
      parent_confidential = nil

      if in_reply_to_discussion_id.present?
        discussion = find_discussion(in_reply_to_discussion_id)

        unless discussion && can?(current_user, :create_note, discussion.noteable)
          note = Note.new
          note.errors.add(:base, _('Discussion to reply to cannot be found'))
          return note
        end

        discussion = discussion.convert_to_discussion! if discussion.can_convert_to_discussion?

        parent_confidential = discussion.notes.first.confidential
        params.merge!(discussion.reply_attributes)
        should_resolve = discussion.resolved?
      end

      note = Note.new(params)
      note.project = project
      note.author = current_user
      note.confidential = should_set_confidential(parent_confidential, note)

      if should_resolve
        note.resolve_without_save(current_user)
      end

      note
    end

    def find_discussion(discussion_id)
      if project
        project.notes.find_discussion(discussion_id)
      else
        Note.find_discussion(discussion_id)
      end
    end

    def should_set_confidential(parent_confidential, note)
      return parent_confidential unless parent_confidential.nil?

      params.delete(:confidential) if can?(current_user, :mark_note_as_confidential, note)
    end
  end
end
