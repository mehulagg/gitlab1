# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::DeleteSourceBranchWorker do
  let_it_be(:merge_request) { create(:merge_request) }
  let_it_be(:user) { create(:user) }

  let(:worker) { described_class.new }

  describe '#perform' do
    context 'with a non-existing merge request' do
      it 'does nothing' do
        expect(::Branches::DeleteService).not_to receive(:new)

        worker.perform(non_existing_record_id, user.id)
      end
    end

    context 'with a non-existing user' do
      it 'does nothing' do
        expect(::Branches::DeleteService).not_to receive(:new)

        worker.perform(merge_request.id, non_existing_record_id)
      end
    end

    context 'with existing user and merge request' do
      it 'calls service to delete source branch' do
        expect_next_instance_of(::Branches::DeleteService) do |instance|
          expect(instance).to receive(:execute).with(merge_request.source_branch)
        end

        worker.perform(merge_request.id, user.id)
      end
    end

    it_behaves_like 'an idempotent worker' do
      let(:merge_request) { create(:merge_request) }
      let(:job_args) { [merge_request.id, user.id] }
    end
  end
end
