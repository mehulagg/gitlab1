# frozen_string_literal: true

RSpec.shared_context 'with project with approval rules' do
  let_it_be(:approver) { create(:user) }
  let_it_be(:author) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, :repository, group: group) }

  before do
    stub_licensed_features(multiple_approval_rules: true)

    [approver, author].each do |member|
      project.add_maintainer(member)
    end
  end

  let_it_be(:regular_rules) do
    Array.new(3) do |i|
      create(:approval_project_rule, project: project, users: [approver], name: "Regular Rule #{i}")
    end
  end
end
