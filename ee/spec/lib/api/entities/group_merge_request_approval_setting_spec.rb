# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::GroupMergeRequestApprovalSetting do
  let(:group_merge_request_approval_setting) { build(:group_merge_request_approval_setting) }

  subject { described_class.new(group_merge_request_approval_setting).as_json }

  it 'exposes correct attributes' do
    expect(subject.keys).to match(
      [
        :allow_author_approval,
        :allow_committer_approval,
        :allow_overrides_to_approver_list_per_merge_request,
        :retain_approvals_on_push,
        :require_password_to_approve
      ]
    )
  end
end
