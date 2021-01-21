# frozen_string_literal: true

module EE
  # PostReceive EE mixin
  #
  # This module is intended to encapsulate EE-specific model logic
  # and be prepended in the `PostReceive` worker
  module PostReceive
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    private

    def after_project_changes_hooks(project, user, refs, changes)
      super

      if audit_push?(project)
        ::RepositoryPushAuditEventWorker.perform_async(changes, project.id, user.id)
      end

      if ::Gitlab::Geo.primary?
        ::Geo::RepositoryUpdatedService.new(project.repository, refs: refs, changes: changes).execute
      end
    end

    def process_wiki_changes(post_received, wiki)
      super

      # TODO: Support Geo for group wikis.
      # https://gitlab.com/gitlab-org/gitlab/-/issues/208147
      return unless wiki.is_a?(ProjectWiki)

      if ::Gitlab::Geo.primary?
        ::Geo::RepositoryUpdatedService.new(wiki.repository).execute
      end
    end

    override :replicate_snippet_changes
    def replicate_snippet_changes(snippet)
      if ::Gitlab::Geo.primary?
        # We don't use Geo::RepositoryUpdatedService anymore as
        # it's already deprecated. See https://gitlab.com/groups/gitlab-org/-/epics/2809
        snippet.snippet_repository.replicator.handle_after_update if snippet.snippet_repository
      end
    end

    def audit_push?(project)
      project.push_audit_events_enabled? && !::Gitlab::Database.read_only?
    end
  end
end
