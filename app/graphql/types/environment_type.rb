# frozen_string_literal: true

module Types
  class EnvironmentType < BaseObject
    graphql_name 'Environment'
    description 'Describes where code is deployed for a project'

    authorize :read_environment

    field :name, GraphQL::STRING_TYPE, null: false,
          description: 'Human-readable name of the environment'

    field :id, GraphQL::ID_TYPE, null: false,
          description: 'ID of the environment'

    field :state, GraphQL::STRING_TYPE, null: false,
          description: 'State of the environment, for example: available/stopped'

    field :path, GraphQL::STRING_TYPE, null: true,
          description: 'The path to the environment. Will always return null '\
                        'if `graphql_expose_environment_path` feature flag is disabled'

    field :metrics_dashboard, Types::Metrics::DashboardType, null: true,
          description: 'Metrics dashboard schema for the environment',
          resolver: Resolvers::Metrics::DashboardResolver

    field :latest_opened_most_severe_alert,
          Types::AlertManagement::AlertType,
          null: true,
          description: 'The most severe open alert for the environment. If multiple alerts have equal severity, the most recent is returned'

    def path
      object.path unless Feature.disabled?(:graphql_expose_environment_path)
    end
  end
end
