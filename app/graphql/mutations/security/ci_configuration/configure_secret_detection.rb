# frozen_string_literal: true

module Mutations
  module Security
    module CiConfiguration
      class ConfigureSecretDetection < BaseMutation
        include FindsProject

        graphql_name 'ConfigureSecretDetection'
        description <<~DESC
          Configure Secret Detection for a project by creating a Merge Request
          that creates a .gitlab-ci.yml file with Secret Detection enabled.
        DESC

        argument :project_path, GraphQL::ID_TYPE,
          required: true,
          description: 'Full path of the project.'

        field :status, GraphQL::STRING_TYPE, null: false,
          description: 'Status of creating the commit for the supplied Secret Detection CI configuration.'

        field :success_path, GraphQL::STRING_TYPE, null: true,
          description: 'Redirect path to use when the response is successful.'

        authorize :push_code

        def resolve(project_path:)
          project = authorized_find!(project_path)

          result = ::Security::CiConfiguration::SecretDetectionCreateService.new(project, current_user, {}).execute
          prepare_response(result)
        end

        private

        def prepare_response(result)
          {
            status: result.status.to_s,
            success_path: result.payload[:success_path],
            errors: result.errors
          }
        end
      end
    end
  end
end
