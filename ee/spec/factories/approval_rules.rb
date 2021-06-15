# frozen_string_literal: true

FactoryBot.define do
  factory :approval_merge_request_rule do
    merge_request
    sequence(:name) { |n| "#{ApprovalRuleLike::DEFAULT_NAME}-#{n}" }
  end

  factory :approval_merge_request_rule_source do
    approval_merge_request_rule
    approval_project_rule
  end

  factory :code_owner_rule, parent: :approval_merge_request_rule do
    merge_request
    rule_type { :code_owner }
    sequence(:name) { |n| "*-#{n}.js" }
    section { Gitlab::CodeOwners::Entry::DEFAULT_SECTION }
  end

  factory :report_approver_rule, parent: :approval_merge_request_rule do
    merge_request
    rule_type { :report_approver }
    report_type { :vulnerability }
    sequence(:name) { |n| "*-#{n}.js" }

    trait :requires_approval do
      approvals_required { rand(1..ApprovalProjectRule::APPROVALS_REQUIRED_MAX) }
    end

    trait :vulnerability do
      name { ApprovalRuleLike::DEFAULT_NAME_FOR_VULNERABILITY_REPORT }
      report_type { :vulnerability }
    end

    trait :license_scanning do
      name { ApprovalRuleLike::DEFAULT_NAME_FOR_LICENSE_REPORT }
      report_type { :license_scanning }
    end

    trait :code_coverage do
      name { ApprovalRuleLike::DEFAULT_NAME_FOR_COVERAGE }
      report_type { :code_coverage }
    end
  end

  factory :any_approver_rule, parent: :approval_merge_request_rule do
    rule_type { :any_approver }
    name { "All Members" }
  end

  factory :approval_project_rule do
    project
    sequence(:name) { |n| "#{ApprovalRuleLike::DEFAULT_NAME}-#{n}" }
    rule_type { :regular }

    trait :requires_approval do
      approvals_required { rand(1..ApprovalProjectRule::APPROVALS_REQUIRED_MAX) }
    end

    trait :vulnerability_report do
      rule_type { :report_approver }
      name { ApprovalRuleLike::DEFAULT_NAME_FOR_VULNERABILITY_REPORT }
    end

    trait :vulnerability do
      vulnerability_report
    end

    trait :license_scanning do
      name { ApprovalRuleLike::DEFAULT_NAME_FOR_LICENSE_REPORT }
      rule_type { :report_approver }
    end

    trait :code_coverage do
      name { ApprovalRuleLike::DEFAULT_NAME_FOR_COVERAGE }
      rule_type { :report_approver }
    end
  end
end
