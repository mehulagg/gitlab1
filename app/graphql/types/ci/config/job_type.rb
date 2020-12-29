# frozen_string_literal: true

module Types
  module Ci
    # rubocop: disable Graphql/AuthorizeTypes
    module Config
      class JobType < BaseObject
        graphql_name 'CiConfigJob'

        field :name, GraphQL::STRING_TYPE, null: true,
              description: 'Name of the job'
        field :group_name, GraphQL::STRING_TYPE, null: true,
              description: 'Name of the job group'
        field :stage, GraphQL::STRING_TYPE, null: true,
              description: 'Name of the job stage'
        field :needs, Types::Ci::Config::NeedType.connection_type, null: true,
              description: 'Builds that must complete before the jobs run'
        field :allow_failure, GraphQL::BOOLEAN_TYPE, null: true,
              description:  'Allow job to fail'
        field :before_script, [GraphQL::STRING_TYPE], null: true,
              description: 'Override a set of commands that are executed before job'
        field :script, [GraphQL::STRING_TYPE], null: true,
              description: 'Shell script that is executed by a runner'
        field :after_script, [GraphQL::STRING_TYPE], null: true,
              description: 'Override a set of commands that are executed after job'
        field :when, GraphQL::STRING_TYPE, null: true,
              description: 'When to run job'
        field :environment, GraphQL::STRING_TYPE, null: true,
              description: 'Name of an environment to which the job deploys'
        field :except, GraphQL::STRING_TYPE, null: true,
              description: 'Limit when jobs are not created'
        field :only, GraphQL::STRING_TYPE, null: true,
              description: 'Limit when jobs are created'
        field :tags, GraphQL::STRING_TYPE, null: true,
              description: 'List of tags that are used to select a runner'
      end
    end
  end
end
