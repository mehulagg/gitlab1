# frozen_string_literal: true

module Mutations
  module Commits
    class Create < BaseMutation
      include ResolvesProject

      graphql_name 'CommitCreate'

      argument :project_path, GraphQL::ID_TYPE,
               required: true,
               description: 'Project full path the branch is associated with'

      argument :branch, GraphQL::STRING_TYPE,
               required: true,
               description: 'Name of the branch'

      argument :message,
               GraphQL::STRING_TYPE,
               required: true,
               description: copy_field_description(Types::CommitType, :message)

      argument :actions,
               [Types::CommitActionType],
               required: true,
               description: 'Array of action hashes to commit as a batch'

      argument :request_source, GraphQL::STRING_TYPE,
               required: false,
               description: 'Request source'

      field :commit,
            Types::CommitType,
            null: true,
            description: 'The commit after mutation'

      authorize :push_code

      def resolve(project_path:, branch:, message:, actions:, request_source: nil)
        project = authorized_find!(full_path: project_path)

        attributes = {
          commit_message: message,
          branch_name: branch,
          start_branch: branch,
          actions: actions.map { |action| action.to_h }
        }

        result = ::Files::MultiService.new(project, current_user, attributes).execute

        increase_commit_counter(result, request_source)

        {
          commit: (project.repository.commit(result[:result]) if result[:status] == :success),
          errors: Array.wrap(result[:message])
        }
      end

      private

      def find_object(full_path:)
        resolve_project(full_path: full_path)
      end

      def increase_commit_counter(result, request_source)
        return unless result[:status] == :success
        return unless request_source == 'static_site_editor'

        Gitlab::UsageDataCounters::StaticSiteEditorCounter.increment_commits_count
      end
    end
  end
end
