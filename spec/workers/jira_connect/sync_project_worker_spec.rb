# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JiraConnect::SyncProjectWorker, factory_default: :keep do
  describe '#perform' do
    let_it_be(:project) { create_default(:project) }
    let!(:mr_with_jira_title) { create(:merge_request, :unique_branches, title: 'TEST-123') }
    let!(:mr_with_jira_description) { create(:merge_request, :unique_branches, description: 'TEST-323') }
    let!(:mr_with_other_title) { create(:merge_request, :unique_branches) }
    let!(:jira_subscription) { create(:jira_connect_subscription, namespace: project.namespace) }

    let(:jira_connect_sync_service) { JiraConnect::SyncService.new(project) }
    let(:job_args) { [project.id] }

    before do
      stub_request(:post, 'https://sample.atlassian.net/rest/devinfo/0.10/bulk').to_return(status: 200, body: '', headers: {})

      jira_connect_sync_service
      allow(JiraConnect::SyncService).to receive(:new) { jira_connect_sync_service }
    end

    context 'when the project is not found' do
      it 'does not raise an error' do
        expect { described_class.new.perform('non_existing_record_id') }.not_to raise_error
      end
    end

    it 'avoids N+1 database queries' do
      control_count = ActiveRecord::QueryRecorder.new { described_class.new.perform(project.id) }.count

      create(:merge_request, :unique_branches, title: 'TEST-123')

      expect { described_class.new.perform(project.id) }.not_to exceed_query_limit(control_count)
    end

    it_behaves_like 'an idempotent worker' do
      it 'syncs merge requests with Jira references in title or description' do
        expect(jira_connect_sync_service).to receive(:execute)
          .exactly(IdempotentWorkerHelper::WORKER_EXEC_TIMES).times
          .with(merge_requests: [mr_with_jira_description, mr_with_jira_title])

        subject
      end

      context 'when the number of merge requests to sync is higher than the limit' do
        let!(:most_recent_merge_request) { create(:merge_request, :unique_branches, description: 'TEST-323', title: 'TEST-123') }

        before do
          stub_const("#{described_class}::MERGE_REQUEST_LIMIT", 1)
        end

        it 'syncs only the most recent merge requests within the limit' do
          expect(jira_connect_sync_service).to receive(:execute)
            .exactly(IdempotentWorkerHelper::WORKER_EXEC_TIMES).times
            .with(merge_requests: [most_recent_merge_request])

          subject
        end
      end
    end
  end
end
