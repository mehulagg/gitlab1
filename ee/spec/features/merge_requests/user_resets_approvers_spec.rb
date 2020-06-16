# frozen_string_literal: true

require 'spec_helper'

describe 'Merge Requests > User resets approvers', :js do
  include FeatureApprovalHelper

  let(:project) { create(:project, :repository) }
  let(:user) { project.creator }
  let(:first_user) { create(:user) }
  let(:project_approvers) { create_list(:user, 3) }
  let(:merge_request) do
    create(:merge_request, approval_users: [first_user], title: 'Bugfix1', source_project: project)
  end
  let!(:rule) { create(:approval_project_rule, project: project, users: project_approvers, approvals_required: 1 )}

  before do
    stub_licensed_features(multiple_approval_rules: true)

    project_approvers.each do |approver|
      project.add_developer(approver)
    end

    merge_request.approvals.create!(user: first_user)

    project.add_developer(user)
    sign_in(user)
    visit edit_project_merge_request_path(project, merge_request)

    wait_for_requests
  end

  it 'resets approvers for merge requests' do
    expect_avatar(find('.js-members'), first_user)

    click_button 'Reset to project defaults'

    wait_for_requests

    expect_avatar(find('.js-members'), project_approvers)

    click_button 'Save changes'

    wait_for_requests

    expect(page).to have_content 'Requires approval'
  end
end
