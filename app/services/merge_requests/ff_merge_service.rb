# frozen_string_literal: true

module MergeRequests
  # MergeService class
  #
  # Do git fast-forward merge and in case of success
  # mark merge request as merged and execute all hooks and notifications
  # Executed when you do fast-forward merge via GitLab UI
  #
  class FfMergeService < MergeRequests::MergeService
    private

    def commit
      ff_merge = repository.ff_merge(current_user,
                                     source,
                                     merge_request.target_branch,
                                     merge_request: merge_request)

      if merge_request.squash_on_merge?
        merge_request.update_column(:squash_commit_sha, merge_request.in_progress_merge_commit_sha)
      end

      ff_merge
    rescue Gitlab::Git::PreReceiveError => e
      Gitlab::ErrorTracking.track_exception(e, pre_receive_message: e.raw_message, merge_request_id: merge_request&.id)
      raise MergeError, e.message
    rescue StandardError => e
      raise MergeError, "Something went wrong during merge: #{e.message}"
    ensure
      merge_request.update_and_mark_in_progress_merge_commit_sha(nil)
    end
  end
end
