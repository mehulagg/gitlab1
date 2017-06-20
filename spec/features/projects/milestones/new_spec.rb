require 'spec_helper'

feature 'Creating a new project milestone', :feature, :js do
  let(:user) { create(:user) }
  let(:project) { create(:empty_project, name: 'test', namespace: user.namespace) }

  before do
    login_as(user)
    visit new_namespace_project_milestone_path(project.namespace, project)
  end

  it 'description has autocomplete' do
    find('#milestone_description').native.send_keys('')
    fill_in 'milestone_description', with: '@'

    expect(page).to have_selector('.atwho-view')
  end
end
