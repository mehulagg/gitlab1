# frozen_string_literal: true

module TodosDestroyer
  class DestroyedIssuableWorker
    include ApplicationWorker
    include TodosDestroyerQueue

    tags :exclude_from_kubernetes

    idempotent!

    def perform(target_id, target_type)
      ::Todos::Destroy::DestroyedIssuableService.new(target_id, target_type).execute
    end
  end
end
