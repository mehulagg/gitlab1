# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ProjectApprovals do
  let_it_be(:group)    { create(:group_with_members) }
  let_it_be(:user)     { create(:user) }
  let_it_be(:user2)    { create(:user) }
  let_it_be(:admin)    { create(:user, :admin) }
  let_it_be(:project)  { create(:project, :public, :repository, creator: user, namespace: user.namespace, only_allow_merge_if_pipeline_succeeds: false) }
  let_it_be(:approver) { create(:user) }

  let(:url) { "/projects/#{project.id}/approvals" }

  describe 'GET /projects/:id/approvals' do
    context 'when the request is correct' do
      before do
        create(:approval_project_rule, project: project, users: [approver], groups: [group])

        get api(url, user)
      end

      it 'returns expected boolean values for merge request related attributes' do
        expect(json_response["disable_overriding_approvers_per_merge_request"]).to be false
        expect(json_response["merge_requests_author_approval"]).to be false
        expect(json_response["merge_requests_disable_committers_approval"]).to be false
        expect(json_response["require_password_to_approve"]).to be false
      end

      it 'returns 200 status' do
        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'matches the response schema' do
        expect(response).to match_response_schema('public_api/v4/project_approvers', dir: 'ee')
      end
    end

    it 'only shows approver groups that are visible to the user' do
      private_group = create(:group, :private)
      create(:approval_project_rule, project: project, users: [approver], groups: [private_group])

      get api(url, user)

      expect(response).to match_response_schema('public_api/v4/project_approvers', dir: 'ee')
      expect(json_response["approver_groups"]).to be_empty
    end
  end

  describe 'POST /projects/:id/approvals' do
    shared_examples_for 'a user with access' do
      context 'when missing parameters' do
        it 'returns 400 status' do
          post api(url, current_user)

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when the request is correct' do
        it 'returns 201 status' do
          post api(url, current_user), params: { approvals_before_merge: 3 }

          expect(response).to have_gitlab_http_status(:created)
        end

        it 'matches the response schema' do
          post api(url, current_user), params: { approvals_before_merge: 3 }

          expect(response).to match_response_schema('public_api/v4/project_approvers', dir: 'ee')
        end

        it 'changes settings properly' do
          project.approvals_before_merge = 2
          project.reset_approvals_on_push = false
          project.disable_overriding_approvers_per_merge_request = true
          project.merge_requests_author_approval = false
          project.merge_requests_disable_committers_approval = true
          project.require_password_to_approve = false
          project.save

          settings = {
            approvals_before_merge: 4,
            reset_approvals_on_push: true,
            disable_overriding_approvers_per_merge_request: false,
            merge_requests_author_approval: true,
            merge_requests_disable_committers_approval: false,
            require_password_to_approve: true
          }

          post api(url, current_user), params: settings

          expect(json_response.symbolize_keys).to include(settings)
        end

        it 'only shows approver groups that are visible to the current user' do
          private_group = create(:group, :private)
          project.approver_groups.create(group: private_group)

          post api(url, current_user), params: { approvals_before_merge: 3 }

          expect(response).to match_response_schema('public_api/v4/project_approvers', dir: 'ee')
          expect(json_response["approver_groups"].size).to eq(visible_approver_groups_count)
        end
      end
    end

    shared_examples 'updates merge requests settings when possible' do
      using RSpec::Parameterized::TableSyntax

      where(:permission_value, :param_value, :final_value) do
        false | false | false
        false | true  | false
        true  | false | false
        true  | true  | true
      end

      with_them do
        before do
          project.update_column(setting, false)

          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(current_user, permission, project).and_return(permission_value)
        end

        it 'changes settings properly' do
          settings = {
            setting => param_value
          }

          post api(url, current_user), params: settings

          expect(project.reload[setting]).to eq(final_value)
        end
      end
    end

    context 'as a project admin' do
      it_behaves_like 'a user with access' do
        let(:current_user) { user }
        let(:visible_approver_groups_count) { 0 }
      end
    end

    context 'as a global admin' do
      it_behaves_like 'a user with access' do
        let(:current_user) { admin }
        let(:visible_approver_groups_count) { 1 }
      end

      context 'updates merge requests settings' do
        it_behaves_like 'updates merge requests settings when possible' do
          let(:current_user) { admin }
          let(:permission) { :modify_approvers_rules }
          let(:setting) { :disable_overriding_approvers_per_merge_request }
        end

        it_behaves_like 'updates merge requests settings when possible' do
          let(:current_user) { admin }
          let(:permission) { :modify_merge_request_committer_setting }
          let(:setting) { :merge_requests_disable_committers_approval }
        end

        it_behaves_like 'updates merge requests settings when possible' do
          let(:current_user) { admin }
          let(:permission) { :modify_merge_request_author_setting }
          let(:setting) { :merge_requests_author_approval }
        end
      end
    end

    context 'as a user without access' do
      it 'returns 403' do
        post api(url, user2), params: { approvals_before_merge: 4 }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
