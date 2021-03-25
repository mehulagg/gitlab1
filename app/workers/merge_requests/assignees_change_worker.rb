# frozen_string_literal: true

class MergeRequests::AssigneesChangeWorker
  include ApplicationWorker

  feature_category :source_code_management
  urgency :high
  idempotent!

  def perform(merge_request_id, user_id, old_assignee_ids)
    merge_request = MergeRequest.find(merge_request_id)
    current_user = User.find(user_id)

    # if a user was added and then removed, or removed and then added
    # while waiting for this job to run, assume that nothing happened.
    users = User.id_in(old_assignee_ids - merge_request.assignee_ids)

    return if users.empty?

    service = ::MergeRequests::UpdateAssigneesService.new(
      merge_request.target_project,
      current_user
    )

    service.handle_assignee_changes(merge_request, users)
  rescue ActiveRecord::RecordNotFound
  end
end
