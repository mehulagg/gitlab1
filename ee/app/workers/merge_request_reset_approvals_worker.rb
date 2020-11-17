# frozen_string_literal: true

class MergeRequestResetApprovalsWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker

  feature_category :code_review
  urgency :high
  worker_resource_boundary :cpu
  loggable_arguments 2, 3

  # rubocop: disable CodeReuse/ActiveRecord
  def perform(project_id, user_id, ref, newrev)
    project = Project.find_by(id: project_id)
    return unless project

    user = User.find_by(id: user_id)
    return unless user

    EE::MergeRequests::ResetApprovalsService.new(project, user).execute(ref, newrev)
  end
  # rubocop: enable CodeReuse/ActiveRecord
end
