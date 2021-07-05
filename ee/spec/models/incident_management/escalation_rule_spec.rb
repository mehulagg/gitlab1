# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IncidentManagement::EscalationRule do
  let_it_be(:policy) { create(:incident_management_escalation_policy) }
  let_it_be(:schedule) { create(:incident_management_oncall_schedule, project: policy.project) }

  subject { build(:incident_management_escalation_rule, policy: policy) }

  it { is_expected.to be_valid }

  describe 'associations' do
    it { is_expected.to belong_to(:policy) }
    it { is_expected.to belong_to(:oncall_schedule) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:elapsed_time_seconds) }
    it { is_expected.to validate_numericality_of(:elapsed_time_seconds).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(24.hours) }
    it { is_expected.to validate_uniqueness_of(:policy_id).scoped_to([:oncall_schedule_id, :status, :elapsed_time_seconds] ).with_message('must have a unique schedule, status, and elapsed time') }

    it 'validates the number of rules' do
      policy = create(:incident_management_escalation_policy, rule_count: 10)
      rule = build(:incident_management_escalation_rule, policy: policy)

      expect(rule).not_to be_valid
      expect(rule.errors).to contain_exactly("cannot have more than #{described_class::MAX_RULE_PER_POLICY_COUNT} rules")
    end
  end
end
