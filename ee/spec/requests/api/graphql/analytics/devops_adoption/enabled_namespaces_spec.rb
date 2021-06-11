# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'devopsAdoptionEnabledNamespaces' do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user, :admin) }
  let_it_be(:group) { create(:group, name: 'my-group') }

  let_it_be(:enabled_namespace) do
    create(:devops_adoption_enabled_namespace, namespace: group, display_namespace: group)
  end

  let_it_be(:expected_metrics) do
    result = {}
    Analytics::DevopsAdoption::Snapshot::BOOLEAN_METRICS.each.with_index do |m, i|
      result[m] = i.odd?
    end
    Analytics::DevopsAdoption::Snapshot::NUMERIC_METRICS.each do |m|
      result[m] = rand(10)
    end
    result[:total_projects_count] += 10
    result
  end

  let_it_be(:snapshot) do
    create(:devops_adoption_snapshot, namespace: group, **expected_metrics)
  end

  let(:query) do
    metrics = Analytics::DevopsAdoption::Snapshot::ADOPTION_METRICS.map { |m| m.to_s.camelize(:lower) }

    graphql_query_for(:devopsAdoptionEnabledNamespaces, { display_namespace_id: group.to_gid.to_s }, %(
      nodes {
        id
        namespace {
          name
        }
        displayNamespace {
          name
        }
        latestSnapshot {
          #{metrics.join(' ')}
        }
      }
    ))
  end

  before do
    stub_licensed_features(instance_level_devops_adoption: true, group_level_devops_adoption: true)

    post_graphql(query, current_user: current_user)
  end

  it 'returns measurement objects' do
    expected_snapshot = expected_metrics.map do |key, value|
      [key.to_s.camelize(:lower), value]
    end.to_h

    expect(graphql_data['devopsAdoptionEnabledNamespaces']['nodes']).to eq([
      {
        'id' => enabled_namespace.to_gid.to_s,
        'namespace' => { 'name' => group.name },
        'displayNamespace' => { 'name' => group.name },
        'latestSnapshot' => expected_snapshot
      }
    ])
  end
end
