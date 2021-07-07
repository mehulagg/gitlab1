# frozen_string_literal: true

module Gitlab
  module GithubImport
    # Module that provides methods shared by the various workers used for
    # importing GitHub projects.
    module ReschedulingMethods
      attr_reader :importer_metadata

      # project_id - The ID of the GitLab project to import the note into.
      # hash - A Hash containing the details of the GitHub object to import.
      # notify_key - The Redis key to notify upon completion, if any.
      # rubocop: disable CodeReuse/ActiveRecord
      def perform(project_id, hash, notify_key = nil, importer_metadata = nil)
        @importer_metadata = importer_metadata

        project = Project.find_by(id: project_id)

        return notify_waiter(notify_key) unless project

        client = GithubImport.new_client_for(project, parallel: true)

        if try_import(project, client, hash)
          notify_waiter(notify_key)
        else
          # In the event of hitting the rate limit we want to reschedule the job
          # so its retried after our rate limit has been reset.
          self.class.perform_in(
            client.rate_limit_resets_in,
            project.id,
            hash,
            notify_key,
            importer_metadata
          )
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def try_import(...)
        import(...)
        true
      rescue RateLimitError
        false
      end

      def notify_waiter(key = nil)
        JobWaiter.notify(key, jid) if key
      end
    end
  end
end
