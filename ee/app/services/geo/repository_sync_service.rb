module Geo
  class RepositorySyncService < BaseSyncService
    self.type = :repository

    private

    def sync_repository(redownload = false)
      fetch_repository(redownload)

      update_gitattributes

      finish
    rescue Gitlab::Shell::Error,
           Gitlab::Git::RepositoryMirroring::RemoteError => e
      # In some cases repository does not exist, the only way to know about this is to parse the error text.
      # If it does not exist we should consider it as successfully downloaded.
      if e.message.include? Gitlab::GitAccess::ERROR_MESSAGES[:no_repo]
        log_info('Repository is not found, marking it as successfully synced')
        finish
      else
        fail_registry!('Error syncing repository', e)
      end
    rescue Gitlab::Git::Repository::NoRepository => e
      log_info('Setting force_to_redownload flag')
      fail_registry!('Invalid repository', e, force_to_redownload_repository: true)

      log_info('Expiring caches')
      project.repository.after_create
    ensure
      clean_up_temporary_repository if redownload
      expire_repository_caches
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

    # Update info/attributes file using the contents of .gitattributes file from the default branch
    def update_gitattributes
      return if project.default_branch.nil?

      repository.copy_gitattributes(project.default_branch)
    end
  end
end
