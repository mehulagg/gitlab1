# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProtectedBranches::CreateService do
  include ProjectForksHelper

  let(:source_project) { create(:project) }
  let(:target_project) { fork_project(source_project, user, repository: true) }

  let(:user) { source_project.owner }

  let(:params) do
    {
      name: "feature",
      merge_access_levels_attributes: [{ access_level: Gitlab::Access::MAINTAINER }],
      push_access_levels_attributes: [{ access_level: Gitlab::Access::MAINTAINER }]
    }
  end

  describe "#execute" do
    subject(:service) { described_class.new(target_project, user, params) }

    before do
      target_project.add_user(user, :developer)
    end

    context "code_owner_approval_required" do
      context "when unavailable" do
        before do
          stub_licensed_features(code_owner_approval_required: false)

          params[:code_owner_approval_required] = true
        end

        it "ignores incoming params and sets code_owner_approval_required to false" do
          expect { service.execute }.to change(ProtectedBranch, :count).by(1)
          expect(ProtectedBranch.last.code_owner_approval_required).to be_falsy
        end
      end

      context "when available" do
        before do
          stub_licensed_features(code_owner_approval_required: true)
        end

        it "sets code_owner_approval_required to true when param is true" do
          params[:code_owner_approval_required] = true

          expect { service.execute }.to change(ProtectedBranch, :count).by(1)
          expect(ProtectedBranch.last.code_owner_approval_required).to be_truthy
        end

        it "sets code_owner_approval_required to false when param is false" do
          params[:code_owner_approval_required] = false

          expect { service.execute }.to change(ProtectedBranch, :count).by(1)
          expect(ProtectedBranch.last.code_owner_approval_required).to be_falsy
        end
      end
    end

    context "when there are open merge requests" do
      let!(:merge_request) do
        create(:merge_request,
          source_project: source_project,
          target_project: target_project,
          discussion_locked: false
        )
      end

      it "calls MergeRequest::SyncCodeOwnerApprovalRules to update open MRs" do
        expect(::MergeRequests::SyncCodeOwnerApprovalRules).to receive(:new).with(merge_request).and_call_original
        expect { service.execute }.to change(ProtectedBranch, :count).by(1)
      end

      context "when the branch is a wildcard" do
        %w(*ture *eatur* feat*).each do |wildcard|
          before do
            params[:name] = wildcard
          end

          it "calls MergeRequest::SyncCodeOwnerApprovalRules to update open MRs for #{wildcard}" do
            expect(::MergeRequests::SyncCodeOwnerApprovalRules).to receive(:new).with(merge_request).and_call_original
            expect { service.execute }.to change(ProtectedBranch, :count).by(1)
          end
        end
      end
    end

    it 'adds a security audit event entry' do
      expect { service.execute }.to change(::SecurityEvent, :count).by(1)
    end

    context 'with invalid params' do
      let(:params) { nil }

      it "doesn't add a security audit event entry" do
        expect { service.execute }.not_to change(::SecurityEvent, :count)
      end
    end
  end
end
