# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User searches Alert Management alerts', :js do
  let_it_be(:project) { create(:project) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:alerts_service) do
    create(:alerts_service,
      project: project,
    )
  end
  let_it_be(:alert) { create(:alert_management_alert, project: project, status: 'triggered') }

  before_all do
    project.add_developer(developer)
  end

  before do
    sign_in(developer)

    visit project_alert_management_index_path(project)
    wait_for_requests
  end

  context 'when a developer+ displays the alerts list and the alert service is enabled they can search an alert' do
    it 'shows the alert table with an alert for a valid search' do
      expect(page).to have_selector('.filtered-search-wrapper')
      find('.gl-filtered-search-term-input').set('Alert')
      find('.gl-search-box-by-click-search-button').click
      expect(all('.dropdown-menu-selectable').count).to be(1)
    end

    it 'shows the an empty table with an invalid search' do
      find('.gl-filtered-search-term-input').set('dsadadasdasdsa')
      find('.gl-search-box-by-click-search-button').click
      expect(page).not_to have_selector('.dropdown-menu-selectable')
    end
  end
end
