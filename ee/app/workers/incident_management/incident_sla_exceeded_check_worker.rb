# frozen_string_literal: true

module IncidentManagement
  class IncidentSlaExceededCheckWorker
    include ApplicationWorker

    sidekiq_options retry: 3
    include CronjobQueue # rubocop:disable Scalability/CronWorkerContext

    idempotent!
    feature_category :incident_management
    tags :exclude_from_kubernetes

    def perform
      IssuableSla.exceeded_for_issues.exceeded_label_not_applied.find_each do |incident_sla|
        ApplyIncidentSlaExceededLabelWorker.perform_async(incident_sla.issue_id)
      end
    end
  end
end
