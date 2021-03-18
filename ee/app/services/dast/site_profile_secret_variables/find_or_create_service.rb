# frozen_string_literal: true

module Dast
  module SiteProfileSecretVariables
    class FindOrCreateService < BaseContainerService
      def execute
        return error_response(message: 'Insufficient permissions') unless allowed?

        return error_response(message: 'DAST Site Profile param missing') unless site_profile
        return error_response(message: 'Key param missing') unless key
        return error_response(message: 'Value param missing') unless param

        secret_variable = find_or_create_secret_variable

        return error_response(message: secret_variable.errors.full_messages) unless secret_variable.persisted?

        success_response(secret_variable)
      end

      private

      def allowed?
        container.feature_available?(:security_on_demand_scans) &&
          Feature.enabled?(:security_dast_site_profiles_additional_fields, container, default_enabled: :yaml)
      end

      def site_profile
        params[:site_profile]
      end

      def key
        params[:key]
      end

      def value
        params[:value]
      end

      def success_response(secret_variable)
        ServiceResponse.success(payload: secret_variable)
      end

      def error_response(message)
        ServiceResponse.error(message: message)
      end

      def find_or_create_secret_variable
        Dast::SiteProfileSecretVariable.safe_find_or_create_by(dast_site_profile: site_profile, key: key) do |variable|
          variable.raw_value = value
        end
      end
    end
  end
end
