# frozen_string_literal: true

module EE
  module EnvironmentEntity
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      expose :rollout_status, if: -> (*) { can_read_deploy_board? }, using: ::RolloutStatusEntity
      expose :has_opened_alert?, if: -> (*) { can_read_alert_management_alert? }, expose_nil: false, as: :has_opened_alert
    end

    private

    def can_read_deploy_board?
      can?(current_user, :read_deploy_board, environment.project)
    end

    def can_read_alert_management_alert?
      can?(current_user, :read_alert_management_alert, environment.project) &&
        environment.project.feature_available?(:environment_alerts)
    end
  end
end
