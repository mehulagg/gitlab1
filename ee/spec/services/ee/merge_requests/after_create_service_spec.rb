# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::AfterCreateService do
  let_it_be(:merge_request) { create(:merge_request) }

  let(:service_object) { described_class.new(merge_request.target_project, merge_request.author) }

  describe '#execute' do
    subject(:execute) { service_object.execute(merge_request) }

    before do
      allow(SyncSecurityReportsToReportApprovalRulesWorker).to receive(:perform_async)
    end

    it 'refreshes code owners for the merge request' do
      fake_refresh_service = instance_double(::MergeRequests::SyncCodeOwnerApprovalRules)

      expect(::MergeRequests::SyncCodeOwnerApprovalRules)
        .to receive(:new).with(kind_of(MergeRequest)).and_return(fake_refresh_service)
      expect(fake_refresh_service).to receive(:execute)

      execute
    end

    context 'report approvers' do
      it 'refreshes report approvers for the merge request' do
        expect_next_instance_of(::MergeRequests::SyncReportApproverApprovalRules) do |service|
          expect(service).to receive(:execute)
        end

        execute
      end
    end

    context 'when the merge request has actual_head_pipeline' do
      let(:pipeline_id) { 1881 }

      before do
        allow(merge_request).to receive(:head_pipeline_id).and_return(pipeline_id)
        allow(merge_request).to receive(:update_head_pipeline).and_return(true)
      end

      it 'schedules a background job to sync security reports to approval rules' do
        execute

        expect(merge_request).to have_received(:update_head_pipeline).ordered
        expect(SyncSecurityReportsToReportApprovalRulesWorker).to have_received(:perform_async).ordered.with(pipeline_id)
      end
    end

    context 'when the merge request does not have actual_head_pipeline' do
      it 'does not schedule a background job to sync security reports to approval rules' do
        execute

        expect(SyncSecurityReportsToReportApprovalRulesWorker).not_to have_received(:perform_async)
      end
    end
  end
end
