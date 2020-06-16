# frozen_string_literal: true

module Gitlab
  class GitAccessSnippet < GitAccess
    extend ::Gitlab::Utils::Override

    ERROR_MESSAGES = {
      authentication_mechanism: 'The authentication mechanism is not supported.',
      read_snippet: 'You are not allowed to read this snippet.',
      update_snippet: 'You are not allowed to update this snippet.',
      snippet_not_found: 'The snippet you were looking for could not be found.',
      repository_not_found: 'The snippet repository you were looking for could not be found.'
    }.freeze

    alias_method :snippet, :container

    def initialize(actor, snippet, protocol, **kwargs)
      super(actor, snippet, protocol, **kwargs)

      @auth_result_type = nil
      @authentication_abilities &= [:download_code, :push_code]
    end

    override :check
    def check(cmd, changes)
      # TODO: Investigate if expanding actor/authentication types are needed.
      # https://gitlab.com/gitlab-org/gitlab/issues/202190
      if actor && !actor.is_a?(User) && !actor.instance_of?(Key)
        raise ForbiddenError, ERROR_MESSAGES[:authentication_mechanism]
      end

      check_snippet_accessibility!

      super
    end

    private

    override :download_ability
    def download_ability
      :read_snippet
    end

    override :push_ability
    def push_ability
      :update_snippet
    end

    override :project
    def project
      snippet&.project
    end

    override :check_namespace!
    def check_namespace!
      return unless project_snippet?

      super
    end

    override :check_container!
    def check_container!
      return unless project_snippet?

      super
    end

    def project_snippet?
      snippet.is_a?(ProjectSnippet)
    end

    override :check_push_access!
    def check_push_access!
      raise ForbiddenError, ERROR_MESSAGES[:update_snippet] unless user

      check_change_access!
    end

    def check_snippet_accessibility!
      if snippet.blank?
        raise NotFoundError, ERROR_MESSAGES[:snippet_not_found]
      end
    end

    override :can_read_project?
    def can_read_project?
      return true if user&.migration_bot?

      super
    end

    override :check_download_access!
    def check_download_access!
      passed = guest_can_download_code? || user_can_download_code?

      unless passed
        raise ForbiddenError, ERROR_MESSAGES[:read_snippet]
      end
    end

    override :check_change_access!
    def check_change_access!
      unless user_can_push?
        raise ForbiddenError, ERROR_MESSAGES[:update_snippet]
      end

      check_size_before_push!

      changes_list.each do |change|
        # If user does not have access to make at least one change, cancel all
        # push by allowing the exception to bubble up
        check_single_change_access(change)
      end

      check_push_size!
    end

    override :check_single_change_access
    def check_single_change_access(change, _skip_lfs_integrity_check: false)
      Checks::SnippetCheck.new(change, logger: logger).validate!
      Checks::PushFileCountCheck.new(change, repository: repository, limit: Snippet.max_file_limit(user), logger: logger).validate!
    rescue Checks::TimedLogger::TimeoutError
      raise TimeoutError, logger.full_message
    end

    override :no_repo_message
    def no_repo_message
      ERROR_MESSAGES[:repository_not_found]
    end

    override :user_access
    def user_access
      @user_access ||= UserAccessSnippet.new(user, snippet: snippet)
    end

    # TODO: Implement EE/Geo https://gitlab.com/gitlab-org/gitlab/issues/205629
    override :check_custom_action
    def check_custom_action(cmd)
      nil
    end

    override :check_size_limit?
    def check_size_limit?
      return false if user&.migration_bot?

      super
    end
  end
end
