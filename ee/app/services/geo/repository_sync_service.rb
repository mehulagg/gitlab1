# frozen_string_literal: true

module Geo
  class RepositorySyncService < BaseSyncService
    class ObjectPoolNotFoundError < StandardError
      def initialize(msg="Object pool not found")
        super
      end
    end

    self.type = :repository

    private

    def sync_repository
      fetch_repository
      update_root_ref
      if need_to_create_object_pool?
        create_object_pool
        mark_no_object_pool!
        return
      end
      mark_sync_as_successful
    rescue Gitlab::Shell::Error, Gitlab::Git::BaseError => e
      # In some cases repository does not exist, the only way to know about this is to parse the error text.
      # If it does not exist we should consider it as successfully downloaded.
      if e.message.include? Gitlab::GitAccess::ERROR_MESSAGES[:no_repo]
        log_info('Repository is not found, marking it as successfully synced')
        mark_sync_as_successful(missing_on_primary: true)
      else
        fail_registry!('Error syncing repository', e)
      end
    rescue Gitlab::Git::Repository::NoRepository => e
      log_info('Setting force_to_redownload flag')
      fail_registry!('Invalid repository', e, force_to_redownload_repository: true)

      log_info('Expiring caches')
      project.repository.after_create
    ensure
      expire_repository_caches
      execute_housekeeping
    end

    def expire_repository_caches
      log_info('Expiring caches')
      project.repository.after_sync
    end

    def ssh_url_to_repo
      "#{primary_ssh_path_prefix}#{project.full_path}.git"
    end

    def repository
      project.repository
    end

    def need_to_create_object_pool?
      project.has_pool_repository? && !project.pool_repository.object_pool.exists?
    end

    def create_object_pool
      ::Geo::CreateObjectPoolWorker.perform_async(project.pool_repository.id)
    end

    def mark_no_object_pool!
      registry.fail_sync!(type, 'Error syncing repository', ObjectPoolNotFoundError.new)
    end

    def ensure_repository
      project.ensure_repository
    end

    def update_root_ref
      # Find the remote root ref, using a JWT header for authentication
      repository.with_config(jwt_authentication_header) do
        project.update_root_ref(GEO_REMOTE_NAME)
      end
    end

    def schedule_repack
      GitGarbageCollectWorker.perform_async(@project.id, :full_repack, lease_key)
    end

    def execute_housekeeping
      Geo::ProjectHousekeepingService.new(project).execute
    end
  end
end
