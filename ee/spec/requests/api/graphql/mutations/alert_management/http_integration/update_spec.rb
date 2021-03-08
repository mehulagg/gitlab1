# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating an existing HTTP Integration' do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:integration) { create(:alert_management_http_integration, project: project) }

  let(:payload_example) do
    {
      'alert' => { 'name' => 'Test alert' },
      'started_at' => Time.current.strftime('%d %B %Y, %-l:%M%p (%Z)')
    }.to_json
  end

  let(:payload_attribute_mappings) do
    [
      { fieldName: 'TITLE', path: %w[alert name], type: 'STRING' },
      { fieldName: 'START_TIME', path: %w[started_at], type: 'DATETIME', label: 'Start time' }
    ]
  end

  let(:mutation) do
    variables = {
      id: GitlabSchema.id_from_object(integration).to_s,
      name: 'Modified Name',
      active: false,
      payload_example: payload_example,
      payload_attribute_mappings: payload_attribute_mappings
    }
    graphql_mutation(:http_integration_update, variables) do
      <<~QL
         clientMutationId
         errors
         integration {
           id
           name
           active
           url
         }
      QL
    end
  end

  let(:mutation_response) { graphql_mutation_response(:http_integration_update) }

  before do
    project.add_maintainer(current_user)

    stub_licensed_features(multiple_alert_http_integrations: true)
  end

  it_behaves_like 'updating an existing HTTP integration'
  it_behaves_like 'validating the payload_example'
  it_behaves_like 'validating the payload_attribute_mappings'
end
