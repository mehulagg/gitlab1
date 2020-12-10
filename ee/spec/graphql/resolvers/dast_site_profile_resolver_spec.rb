# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::DastSiteProfileResolver do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:dast_site_profile1) { create(:dast_site_profile, project: project) }
  let_it_be(:dast_site_profile2) { create(:dast_site_profile, project: project) }

  before do
    project.add_maintainer(current_user)
  end

  specify do
    expect(described_class).to have_nullable_graphql_type(Types::DastSiteProfileType.connection_type)
  end

  context 'when resolving a single DAST site profile' do
    subject { sync(single_dast_site_profile(id: dast_site_profile1.to_global_id)) }

    it { is_expected.to contain_exactly(dast_site_profile1) }
  end

  context 'when resolving multiple DAST site profiles' do
    subject { sync(dast_site_profiles) }

    it { is_expected.to contain_exactly(dast_site_profile1, dast_site_profile2) }
  end

  private

  def dast_site_profiles(args = {}, context = { current_user: current_user })
    resolve(described_class, obj: project, args: args, ctx: context)
  end

  def single_dast_site_profile(args = {}, context = { current_user: current_user })
    resolve(described_class, obj: project, args: args, ctx: context)
  end
end
