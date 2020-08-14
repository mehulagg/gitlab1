# frozen_string_literal: true

module Gitlab
  module Metrics
    module Dashboard
      module Validator
        DASHBOARD_SCHEMA_PATH = 'lib/gitlab/metrics/dashboard/validator/schemas/dashboard.json'.freeze

        class << self
          def validate(content, schema_path = DASHBOARD_SCHEMA_PATH, dashboard_path: nil, project: nil)
            errors = _validate(content, schema_path, dashboard_path: dashboard_path, project: project)
            errors.empty?
          end

          def validate!(content, schema_path = DASHBOARD_SCHEMA_PATH, dashboard_path: nil, project: nil)
            errors = _validate(content, schema_path, dashboard_path: dashboard_path, project: project)
            errors.empty? || raise(errors.first)
          end

          private

          def _validate(content, schema_path, dashboard_path: nil, project: nil)
            client = Validator::Client.new(content, schema_path, dashboard_path: dashboard_path, project: project)
            client.execute
          end
        end
      end
    end
  end
end
