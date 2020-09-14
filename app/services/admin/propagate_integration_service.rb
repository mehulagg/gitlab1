# frozen_string_literal: true

module Admin
  class PropagateIntegrationService
    include PropagateService

    def propagate
      update_inherited_integrations
      create_integration_for_projects_without_integration
    end

    private

    # rubocop: disable Cop/InBatches
    # rubocop: disable CodeReuse/ActiveRecord
    def update_inherited_integrations
      Service.where(type: integration.type, inherit_from_id: integration.id).in_batches(of: BATCH_SIZE) do |batch|
        bulk_update_from_integration(batch)
      end
    end
    # rubocop: enable Cop/InBatches
    # rubocop: enable CodeReuse/ActiveRecord

    # rubocop: disable CodeReuse/ActiveRecord
    def bulk_update_from_integration(batch)
      # Retrieving the IDs instantiates the ActiveRecord relation (batch)
      # into concrete models, otherwise update_all will clear the relation.
      # https://stackoverflow.com/q/34811646/462015
      batch_ids = batch.pluck(:id)

      Service.transaction do
        batch.update_all(service_hash)

        if data_fields_present?
          integration.data_fields.class.where(service_id: batch_ids).update_all(data_fields_hash)
        end
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def service_hash
      @service_hash ||= integration.to_service_hash
        .tap { |json| json['inherit_from_id'] = integration.id }
    end
  end
end
