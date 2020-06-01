# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Analytics::IssuesAnalyticsController do
  it_behaves_like 'issues analytics controller' do
    let_it_be(:user)  { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project1) { create(:project, :empty_repo, namespace: group) }
    let_it_be(:issue1) { create(:issue, project: project1, confidential: true) }
    let_it_be(:issue2) { create(:issue, project: project1, state: :closed) }

    before do
      group.add_owner(user)
      sign_in(user)
    end

    let(:params) { { namespace_id: group.to_param, project_id: project1.to_param } }
  end
end
