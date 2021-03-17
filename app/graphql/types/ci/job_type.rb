# frozen_string_literal: true

module Types
  module Ci
    class JobType < BaseObject
      graphql_name 'CiJob'
      authorize :read_commit_status

      field :id, GraphQL::ID_TYPE, null: false,
            description: 'ID of the job.'
      field :pipeline, Types::Ci::PipelineType, null: true,
            description: 'Pipeline the job belongs to.'
      field :name, GraphQL::STRING_TYPE, null: true,
            description: 'Name of the job.'
      field :needs, BuildNeedType.connection_type, null: true,
            description: 'References to builds that must complete before the jobs run.'
      field :detailed_status, Types::Ci::DetailedStatusType, null: true,
            description: 'Detailed status of the job.'
      field :scheduled_at, Types::TimeType, null: true,
            description: 'Schedule for the build.'
      field :artifacts, Types::Ci::JobArtifactType.connection_type, null: true,
            description: 'Artifacts generated by the job.'
      field :finished_at, Types::TimeType, null: true,
            description: 'When a job has finished running.'
      field :duration, GraphQL::INT_TYPE, null: true,
            description: 'Duration of the job in seconds.'
      field :short_sha, type: GraphQL::STRING_TYPE, null: false,
            description: 'Short SHA1 ID of the commit.'

      def pipeline
        Gitlab::Graphql::Loaders::BatchModelLoader.new(::Ci::Pipeline, object.pipeline_id).find
      end

      def detailed_status
        object.detailed_status(context[:current_user])
      end

      def artifacts
        if object.is_a?(::Ci::Build)
          object.job_artifacts
        end
      end
    end
  end
end
