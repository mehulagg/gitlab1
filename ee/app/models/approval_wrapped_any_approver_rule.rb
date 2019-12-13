# frozen_string_literal: true

# A common state computation interface to wrap around any_approver rule
class ApprovalWrappedAnyApproverRule < ApprovalWrappedRule
  def name
    ''
  end

  def approved_approvers
    filter_approvers(merge_request.approved_by_users)
  end

  def approved?
    strong_memoize(:approved) do
      approvals_left <= 0
    end
  end
end
