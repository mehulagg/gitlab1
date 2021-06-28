# frozen_string_literal: true

module IncidentManagement
  class EscalationPolicy < ApplicationRecord
    self.table_name = 'incident_management_escalation_policies'

    MAX_RULE_COUNT = 10

    belongs_to :project
    has_many :rules, class_name: 'EscalationRule', inverse_of: :policy, foreign_key: 'policy_id', index_errors: true

    validates :project_id, uniqueness: { message: _('can only have one escalation policy') }, on: :create
    validates :name, presence: true, uniqueness: { scope: [:project_id] }, length: { maximum: 72 }
    validates :description, length: { maximum: 160 }
    validates :rules, presence: true
    validate :rules_count_not_exceeded

    accepts_nested_attributes_for :rules

    scope :with_rules, -> { includes(:rules) }

    private

    def rules_count_not_exceeded
      errors.add(:base, "cannot have more than #{MAX_RULE_COUNT} rules") if rules.size > MAX_RULE_COUNT
    end
  end
end
