# frozen_string_literal: true

module Geo
  class PagesDeploymentReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy
    extend ::Gitlab::Utils::Override

    def self.model
      ::PagesDeployment
    end

    def carrierwave_uploader
      model_record.file
    end

    # The feature flag follows the format `geo_#{replicable_name}_replication`,
    # so here it would be `geo_pages_deployment_replication`
    def self.replication_enabled_by_default?
      false
    end

    override :verification_feature_flag_enabled?
    def self.verification_feature_flag_enabled?
      # We are adding verification at the same time as replication, so we
      # don't need to toggle verification separately from replication. When
      # the replication feature flag is off, then verification is also off
      # (see `VerifiableReplicator.verification_enabled?`)
      true
    end
  end
end
