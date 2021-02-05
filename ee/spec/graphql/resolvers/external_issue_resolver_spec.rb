# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ExternalIssueResolver do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }

  context 'when Jira issues are requested' do
    let_it_be(:vulnerability_external_issue_link) { create(:vulnerabilities_external_issue_link) }

    before do
      allow_next_instance_of(::Integrations::Jira::IssueSerializer) do |serializer|
        allow(serializer).to receive(:represent).and_return(serialized_result)
      end
    end

    let(:jira_issue) do
      double(
        id: vulnerability_external_issue_link.external_issue_key,
        summary: 'Issue Title',
        created: Time.at(1606348800).utc,
        updated: Time.at(1606348800).utc,
        resolutiondate: Time.at(1606348800).utc,
        status: double(name: 'To Do'),
        key: 'GV-1',
        labels: [],
        reporter: double(displayName: 'User', accountId: '10000'),
        assignee: nil,
        client: double(options: { site: 'http://jira.com/' })
      )
    end

    let(:serialized_result) do
      {
        'project_id' => vulnerability_external_issue_link.vulnerability.project_id,
        'title' => 'Issue Title',
        'created_at' => '2020-11-26T00:00:00.000Z',
        'updated_at' => '2020-11-26T00:00:00.000Z',
        'closed_at' => '2020-11-26T00:00:00.000Z',
        'status' => 'To Do',
        'labels' => [],
        'author' => {
          'name' => 'User',
          'web_url' => 'http://jira.com/people/10000'
        },
        'assignees' => [],
        'web_url' => 'http://jira.com/browse/GV-1',
        'references' => {
          'relative' => 'GV-1'
        },
        'external_tracker' => 'jira'
      }
    end

    context 'when Jira API responds with nil' do
      before do
        allow_next_instance_of(::Projects::Integrations::Jira::ByIdsFinder) do |issues_finder|
          allow(issues_finder).to receive(:execute).and_return(nil)
        end
      end

      it 'sends request to Jira to fetch issues' do
        params = [vulnerability_external_issue_link.vulnerability.project, [vulnerability_external_issue_link.external_issue_key]]
        expect_next_instance_of(::Projects::Integrations::Jira::ByIdsFinder, *params) do |issues_finder|
          expect(issues_finder).to receive(:execute).and_return(nil)
        end

        batch_sync { resolve_external_issue({}) }
      end

      it 'returns nil' do
        result = batch_sync { resolve_external_issue({}) }
        expect(result).to be_nil
      end
    end

    context 'when Jira API responds with found issues' do
      before do
        allow_next_instance_of(::Projects::Integrations::Jira::ByIdsFinder) do |issues_finder|
          allow(issues_finder).to receive(:execute).and_return(issues: [jira_issue])
        end
      end

      it 'sends request to Jira to fetch issues' do
        params = [vulnerability_external_issue_link.vulnerability.project, [vulnerability_external_issue_link.external_issue_key]]
        expect_next_instance_of(::Projects::Integrations::Jira::ByIdsFinder, *params) do |issues_finder|
          expect(issues_finder).to receive(:execute).and_return(issues: [jira_issue])
        end

        batch_sync { resolve_external_issue({}) }
      end

      it 'returns serialized Jira issues' do
        result = batch_sync { resolve_external_issue({}) }
        expect(result.as_json).to eq(serialized_result)
      end
    end

    context 'when Jira API responds with an integration error' do
      before do
        allow_next_instance_of(::Projects::Integrations::Jira::ByIdsFinder) do |issues_finder|
          allow(issues_finder).to receive(:execute).and_return(error: 'Jira service not configured.')
        end
      end

      it 'raises a GraphQL exception' do
        expect { batch_sync { resolve_external_issue({}) } }.to raise_error(GraphQL::ExecutionError, 'Jira service not configured.')
      end
    end

    context 'when Jira API responds with an request error' do
      before do
        allow_next_instance_of(::Projects::Integrations::Jira::ByIdsFinder) do |issues_finder|
          allow(issues_finder).to receive(:execute).and_return(error: 'Jira service unavailable.')
        end
      end

      it 'raises a GraphQL exception' do
        expect { batch_sync { resolve_external_issue({}) } }.to raise_error(GraphQL::ExecutionError, 'Jira service unavailable.')
      end
    end

    def resolve_external_issue(args)
      resolve(described_class, obj: vulnerability_external_issue_link, args: args, ctx: { current_user: current_user })
    end
  end
end
