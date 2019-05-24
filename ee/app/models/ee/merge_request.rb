# frozen_string_literal: true

module EE
  module MergeRequest
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    include ::Approvable
    include ::Gitlab::Utils::StrongMemoize
    include FromUnion

    prepended do
      include Elastic::MergeRequestsSearch

      has_many :reviews, inverse_of: :merge_request
      has_many :approvals, dependent: :delete_all # rubocop:disable Cop/ActiveRecordDependent
      has_many :approved_by_users, through: :approvals, source: :user
      has_many :approvers, as: :target, dependent: :delete_all # rubocop:disable Cop/ActiveRecordDependent
      has_many :approver_users, through: :approvers, source: :user
      has_many :approver_groups, as: :target, dependent: :delete_all # rubocop:disable Cop/ActiveRecordDependent
      has_many :approval_rules, class_name: 'ApprovalMergeRequestRule', inverse_of: :merge_request
      has_many :draft_notes
      has_one :merge_train

      has_many :blocks_as_blocker,
               class_name: 'MergeRequestBlock',
               foreign_key: :blocking_merge_request_id

      has_many :blocks_as_blockee,
               class_name: 'MergeRequestBlock',
               foreign_key: :blocked_merge_request_id

      has_many :blocking_merge_requests, through: :blocks_as_blockee

      has_many :blocked_merge_requests, through: :blocks_as_blocker

      validate :validate_approval_rule_source

      delegate :sha, to: :head_pipeline, prefix: :head_pipeline, allow_nil: true
      delegate :sha, to: :base_pipeline, prefix: :base_pipeline, allow_nil: true
      delegate :merge_requests_author_approval?, to: :target_project, allow_nil: true

      participant :participant_approvers

      accepts_nested_attributes_for :approval_rules, allow_destroy: true

      state_machine :state do
        after_transition any => [:merged, :closed] do |merge_request|
          next unless merge_request.auto_merge_enabled?

          merge_request.run_after_commit { AutoMergeProcessWorker.perform_async(merge_request.id) }
        end
      end
    end

    class_methods do
      def select_from_union(relations)
        where(id: from_union(relations))
      end

      # This is an ActiveRecord scope in CE
      def with_api_entity_associations
        super.preload(:blocking_merge_requests)
      end
    end

    override :mergeable?
    def mergeable?(skip_ci_check: false)
      return false unless approved?
      return false if merge_blocked_by_other_mrs?

      super
    end

    def merge_blocked_by_other_mrs?
      strong_memoize(:merge_blocked_by_other_mrs) do
        project.feature_available?(:blocking_merge_requests) &&
          blocking_merge_requests.any? { |mr| !mr.merged? }
      end
    end

    override :mergeable_ci_state?
    def mergeable_ci_state?
      return false unless validate_merge_request_pipelines

      super
    end

    def allows_multiple_assignees?
      project.multiple_mr_assignees_enabled? &&
        project.feature_available?(:multiple_merge_request_assignees)
    end

    def supports_weight?
      false
    end

    def validate_merge_request_pipelines
      return true unless project.merge_pipelines_enabled?

      actual_head_pipeline&.latest_merge_request_pipeline?
    end

    def validate_approval_rule_source
      return unless approval_rules.any?

      local_project_rule_ids = approval_rules.map { |rule| rule.approval_merge_request_rule_source&.approval_project_rule_id }
      local_project_rule_ids.compact!

      invalid = if new_record?
                  local_project_rule_ids.to_set != project.approval_rule_ids.to_set
                else
                  (local_project_rule_ids - project.approval_rule_ids).present?
                end

      errors.add(:approval_rules, :invalid_sourcing_to_project_rules) if invalid
    end

    def participant_approvers
      strong_memoize(:participant_approvers) do
        next [] unless approval_needed?

        approval_state.filtered_approvers(code_owner: false, unactioned: true)
      end
    end

    def code_owners
      strong_memoize(:code_owners) do
        ::Gitlab::CodeOwners.for_merge_request(self).freeze
      end
    end

    def has_license_management_reports?
      actual_head_pipeline&.has_reports?(::Ci::JobArtifact.license_management_reports)
    end

    def compare_license_management_reports
      unless has_license_management_reports?
        return { status: :error, status_reason: 'This merge request does not have license management reports' }
      end

      compare_reports(::Ci::CompareLicenseManagementReportsService)
    end

    def has_metrics_reports?
      actual_head_pipeline&.has_reports?(::Ci::JobArtifact.metrics_reports)
    end

    def compare_metrics_reports
      unless has_metrics_reports?
        return { status: :error, status_reason: 'This merge request does not have metrics reports' }
      end

      compare_reports(::Ci::CompareMetricsReportsService)
    end

    def sync_code_owners_with_approvers
      return if merged?

      owners = code_owners

      if owners.present?
        ApplicationRecord.transaction do
          rule = approval_rules.code_owner.first
          rule ||= ApprovalMergeRequestRule.find_or_create_code_owner_rule(
            self,
            ApprovalMergeRequestRule::DEFAULT_NAME_FOR_CODE_OWNER
          )

          rule.users = owners.uniq
        end
      else
        approval_rules.code_owner.delete_all
      end
    end
  end
end
