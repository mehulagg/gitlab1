# frozen_string_literal: true

# Model for join table between ApprovalProjectRule and ProtectedBranch
class ApprovalProjectRulesProtectedBranch < NamespaceShard
  extend SuppressCompositePrimaryKeyWarning
end
