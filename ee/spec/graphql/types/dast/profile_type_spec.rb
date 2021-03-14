# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['DastProfile'] do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:object) { create(:dast_profile, project: project) }
  let_it_be(:user) { create(:user, developer_projects: [project]) }
  let_it_be(:fields) { %i[id name description dastSiteProfile dastScannerProfile branch editPath] }

  specify { expect(described_class.graphql_name).to eq('DastProfile') }
  specify { expect(described_class).to require_graphql_authorizations(:read_on_demand_scans) }

  before do
    stub_licensed_features(security_on_demand_scans: true)
  end

  it { expect(described_class).to have_graphql_fields(fields) }
  it { expect(described_class).to have_graphql_field(:branch, calls_gitaly?: true) }

  describe 'branch field' do
    context 'when the feature flag is disabled' do
      it 'resolves nil' do
        stub_feature_flags(dast_branch_selection: false)

        expect(resolve_field(:branch, object, current_user: user)).to eq(nil)
      end
    end

    context 'when the feature flag is enabled' do
      it 'correctly resolves the field' do
        expected_result = Dast::Branch.new(object)

        expect(resolve_field(:branch, object, current_user: user)).to eq(expected_result)
      end
    end
  end

  describe 'editPath field' do
    it 'correctly resolves the field' do
      expected_result = Gitlab::Routing.url_helpers.edit_project_on_demand_scan_path(project, object)

      expect(resolve_field(:edit_path, object, current_user: user)).to eq(expected_result)
    end
  end
end
