# frozen_string_literal: true

module AutoMerge
  class MergeTrainService < AutoMerge::BaseService
    def execute(merge_request)
      unless merge_request.merge_train
        merge_request.build_merge_train(user: current_user,
                                        target_project: merge_request.target_project,
                                        target_branch: merge_request.target_branch)
      end

      super do
        if merge_request.saved_change_to_auto_merge_enabled?
          SystemNoteService.merge_train(merge_request, project, current_user, merge_request.merge_train)
        end
      end
    end

    def process(merge_request)
      return unless merge_request.merge_train

      ::MergeTrains::RefreshMergeRequestsService.new(project, nil).execute(merge_request)
    end

    def cancel(merge_request, reason: nil, refresh_next: true)
      # Before dropping a merge request from a merge train, get the next
      # merge request in order to refresh it later.
      next_merge_request = merge_request.merge_train.next if refresh_next

      super(merge_request) do
        merge_request.merge_train.delete
        SystemNoteService.cancel_merge_train(merge_request, project, current_user, reason: reason)
        AutoMergeProcessWorker.perform_async(next_merge_request.id) if next_merge_request
      end
    end

    def available_for?(merge_request)
      return false unless merge_request.project.merge_trains_enabled?
      return false if merge_request.for_fork?
      return false unless merge_request.actual_head_pipeline&.complete?
      return false unless merge_request.mergeable_state?(skip_ci_check: true)

      true
    end
  end
end
