# frozen_string_literal: true

module Ci
  module ResourceGroups
    class AssignResourceFromResourceGroupWorker
      include ApplicationWorker

      sidekiq_options retry: 3
      include PipelineQueue

      queue_namespace :pipeline_processing
      feature_category :continuous_delivery

      deduplicate :until_executed
      idempotent!

      def perform(resource_group_id)
        ::Ci::ResourceGroup.find_by_id(resource_group_id).try do |resource_group|
          Ci::ResourceGroups::AssignResourceFromResourceGroupService.new(resource_group.project, nil)
            .execute(resource_group)
        end
      end
    end
  end
end
