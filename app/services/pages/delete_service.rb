# frozen_string_literal: true

module Pages
  class DeleteService < BaseService
    def execute
      project.mark_pages_as_not_deployed # prevents domain from updating config when deleted
      project.pages_domains.delete_all

      DestroyPagesDeploymentsWorker.perform_async(project.id)

      PagesRemoveWorker.perform_async(project.id) if Feature.enabled?(:pages_update_legacy_storage, default_enabled: true)
    end
  end
end
