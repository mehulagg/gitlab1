require 'spec_helper'

RSpec.describe 'Dashboard Active Tab', feature: true do
  before do
    login_as :user
  end

  shared_examples 'page has active tab' do |title|
    it "#{title} tab" do
      expect(page).to have_selector('.nav-sidebar li.active', count: 1)
      expect(find('.nav-sidebar li.active')).to have_content(title)
    end
  end

  context 'on dashboard projects' do
    before do
      visit dashboard_projects_path
    end

    it_behaves_like 'page has active tab', 'Projects'
  end

  context 'on dashboard issues' do
    before do
      visit issues_dashboard_path
    end

    it_behaves_like 'page has active tab', 'Issues'
  end

  context 'on dashboard merge requests' do
    before do
      visit merge_requests_dashboard_path
    end

    it_behaves_like 'page has active tab', 'Merge Requests'
  end

  context 'on dashboard groups' do
    before do
      visit dashboard_groups_path
    end

    it_behaves_like 'page has active tab', 'Groups'
  end
end
