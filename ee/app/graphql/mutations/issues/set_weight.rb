# frozen_string_literal: true

module Mutations
  module Issues
    class SetWeight < ::Mutations::Issues::Base
      graphql_name 'IssueSetWeight'

      argument :weight,
               GraphQL::INT_TYPE,
               required: true,
               description: 'The desired weight for the issue.'

      def resolve(project_path:, iid:, weight:)
        issue = authorized_find!(project_path: project_path, iid: iid)
        project = issue.project

        ::Issues::UpdateService.new(container: project, current_user: current_user, params: { weight: weight })
          .execute(issue)

        {
          issue: issue,
          errors: issue.errors.full_messages
        }
      end
    end
  end
end
