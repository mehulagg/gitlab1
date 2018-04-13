module EE
  module Project
    module ImportStatusStateMachine
      extend ActiveSupport::Concern

      included do
        state_machine :import_status, initial: :none do
          before_transition [:none, :finished, :failed] => :scheduled do |project, _|
            project.import_state&.last_update_scheduled_at = Time.now
          end

          before_transition scheduled: :started do |project, _|
            project.import_state&.last_update_started_at = Time.now
          end

          before_transition scheduled: :failed do |project, _|
            if project.mirror?
              project.import_state.last_update_at = Time.now
              project.import_state.set_next_execution_to_now
            end
          end

          after_transition started: :failed do |project, _|
            if project.mirror? && project.mirror_hard_failed?
              ::NotificationService.new.mirror_was_hard_failed(project)
            end
          end

          after_transition [:scheduled, :started] => [:finished, :failed] do |project, _|
            ::Gitlab::Mirror.decrement_capacity(project.id) if project.mirror?
          end

          before_transition started: :failed do |project, _|
            if project.mirror?
              project.import_state.last_update_at = Time.now

              import_state = project.import_state
              import_state.increment_retry_count
              import_state.set_next_execution_timestamp
            end
          end

          before_transition started: :finished do |project, _|
            if project.mirror?
              timestamp = Time.now
              # TODO: two calls to import_state, make it 1
              project.import_state.last_update_at = timestamp
              project.import_state.last_successful_update_at = timestamp

              import_state = project.import_state
              import_state.reset_retry_count
              import_state.set_next_execution_timestamp
            end

            if ::Gitlab::CurrentSettings.current_application_settings.elasticsearch_indexing?
              project.run_after_commit do
                last_indexed_commit = project.index_status&.last_commit
                ElasticCommitIndexerWorker.perform_async(project.id, last_indexed_commit)
              end
            end
          end

          after_transition [:finished, :failed] => [:scheduled, :started] do |project, _|
            ::Gitlab::Mirror.increment_capacity(project.id) if project.mirror?
          end
        end
      end
    end
  end
end
