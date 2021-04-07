# frozen_string_literal: true

module MergeRequests
  class UpdateAssigneesService < UpdateService
    # a stripped down service that only does what it must to update the
    # assignees, and knows that it does not have to check for other updates.
    # This saves a lot of queries for irrelevant things that cannot possibly
    # change in the execution of this service.
    def execute(merge_request)
      return unless current_user&.can?(:update_merge_request, merge_request)

      old_assignees = merge_request.assignees
      return if old_assignees.map(&:id).to_set == update_attrs[:assignee_ids].to_set # no-change

      merge_request.update!(**update_attrs)

      # Defer the more expensive operations (handle_assignee_changes) to the background
      MergeRequests::HandleAssigneesChangeService
        .new(project, current_user)
        .async_execute(merge_request, old_assignees, execute_hooks: true)
    end

    private

    def assignee_ids
      params.fetch(:assignee_ids).first(1)
    end

    def update_attrs
      @attrs ||= { updated_at: Time.current, updated_by: current_user, assignee_ids: assignee_ids }
    end
  end
end

MergeRequests::UpdateAssigneesService.prepend_if_ee('EE::MergeRequests::UpdateAssigneesService')
