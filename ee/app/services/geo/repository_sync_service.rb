# frozen_string_literal: true

module Geo
  class RepositorySyncService < BaseSyncService
    self.type = :repository

    delegate :pool_repository, :has_pool_repository?, to: :project

    private

    def sync_repository
      fetch_repository
      update_root_ref
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

    def ensure_repository
      project.ensure_repository
    end

    def fast_initial_fetch?
      return if !has_pool_repository? || !pool_repository.object_pool.exists? || repository.exists?

      true
    end

    def fast_initial_geo_fetch(repository)
      repository.geo_fast_initial_fetch(pool_repository, GEO_REMOTE_NAME, remote_url, jwt_authorization_token)
    end

    def initial_fetch(repository)
      return fast_initial_geo_fetch(repository) if fast_initial_fetch?
      ensure_repository
      fetch_geo(repository)
    end

    def update_root_ref
      # Find the remote root ref, using a JWT header for authentication
      repository.with_config(jwt_authentication_header) do
        project.update_root_ref(GEO_REMOTE_NAME)
      end
    end

    def execute_housekeeping
      Geo::ProjectHousekeepingService.new(project, new_repository: new_repository?).execute
    end
  end
end
