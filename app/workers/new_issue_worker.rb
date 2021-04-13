# frozen_string_literal: true

class NewIssueWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker
  include NewIssuable

  feature_category :issue_tracking
  urgency :high
  worker_resource_boundary :cpu
  weight 2

  def perform(issue_id, user_id)
    return unless objects_found?(issue_id, user_id)

    ::EventCreateService.new.open_issue(issuable, user)
    ::NotificationService.new.new_issue(issuable, user)

    issuable.create_cross_references!(user)

    if Feature.enabled?(:issue_perform_after_creation_tasks_async, issuable.project)
      Issues::AfterCreateService
        .new(container: issuable.project, current_user: user)
        .execute(issuable)
    end
  end

  def issuable_class
    Issue
  end
end
