# frozen_string_literal: true

module Namespaces
  class OnboardingProgressWorker
    include ApplicationWorker

    feature_category :subgroups
    urgency :low

    deduplicate :until_executing
    idempotent!

    def perform(namespace_id, action)
      namespace = Namespace.find_by_id(namespace_id)
      return unless namespace && action

      OnboardingProgressService.new(namespace).execute(action: action.to_sym)
    end
  end
end
