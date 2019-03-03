# frozen_string_literal: true
module EE
  module CommitStatusPresenter
    extend ActiveSupport::Concern

    prepended do
      EE_CALLOUT_FAILURE_MESSAGES = const_get(:CALLOUT_FAILURE_MESSAGES).merge(
        protected_environment_failure: 'The environment this job is deploying to is protected. Only users with permission may successfully run this job.',
        downstream_insufficient_bridge_permissions: 'This job could not be executed because of insufficient permissions to create a downstream pipeline.',
        downstream_bridge_project_not_found: 'This job could not be executed because downstream bridge project could not be found.',
        downstream_invalid_bridge_trigger: 'This job could not be executed because downstream pipeline trigger definition is invalid.'
      ).freeze

      EE::CommitStatusPresenter.private_constant :EE_CALLOUT_FAILURE_MESSAGES
    end

    class_methods do
      def callout_failure_messages
        EE_CALLOUT_FAILURE_MESSAGES
      end
    end
  end
end
