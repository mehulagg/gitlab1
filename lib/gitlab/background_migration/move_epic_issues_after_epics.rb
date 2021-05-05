# frozen_string_literal: true

module Gitlab
  module BackgroundMigration
    # rubocop: disable Style/Documentation
    class MoveEpicIssuesAfterEpics
      def perform(start_id, stop_id)
      end
    end
  end
end

Gitlab::BackgroundMigration::MoveEpicIssuesAfterEpics.prepend_mod_with('EE::Gitlab::BackgroundMigration::MoveEpicIssuesAfterEpics')
