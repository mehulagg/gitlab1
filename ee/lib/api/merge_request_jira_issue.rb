# frozen_string_literal: true

module API
  class MergeRequestJiraIssue < ::API::Base
    before { authenticate_non_get! }
    before { check_jira_issue_feature_available! }

    feature_category :source_code_management

    helpers do
      def check_jira_issue_feature_available!
        not_found! unless user_project.jira_issue_association_required_to_merge_enabled?
      end

      def present_jira_issue(merge_request)
        present merge_request, with: ::API::Entities::MergeRequestJiraIssue, current_user: current_user
      end
    end

    resource :projects, requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      segment ':id/merge_requests/:merge_request_iid' do
        # Get the Jira Issue association for a merge request
        #
        # Parameters:
        #   id (required)                 - The ID of a project
        #   merge_request_iid (required)  - IID of MR
        # Examples:
        #   GET /projects/:id/merge_requests/:merge_request_iid/jira_issue
        desc 'Get Jira Issue association for merge request'
        params do
          requires :id, type: String, desc: 'The ID of a project'
          requires :merge_request_iid, types: [Integer, String], desc: 'The IID of a merge request'
        end
        get 'jira_issue' do
          forbidden! unless can?(current_user, :read_merge_request, user_project)

          merge_request = find_merge_request_with_access(declared(params)[:merge_request_iid])

          present_jira_issue(merge_request)
        end
      end
    end
  end
end
