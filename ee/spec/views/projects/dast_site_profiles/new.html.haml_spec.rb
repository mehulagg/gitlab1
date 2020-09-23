# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "projects/dast_site_profiles/new", type: :view do
  before do
    @project = create(:project)
    render
  end

  it 'renders Vue app root' do
    expect(rendered).to have_selector('.js-dast-site-profile-form')
  end

  it 'passes project\'s full path' do
    expect(rendered).to include @project.path_with_namespace
  end

  it 'passes DAST profiles library URL' do
    expect(rendered).to include '/on_demand_scans/profiles#site-profiles'
  end
end
