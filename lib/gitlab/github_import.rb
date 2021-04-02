# frozen_string_literal: true

module Gitlab
  module GithubImport
    def self.refmap
      [:heads, :tags, '+refs/pull/*/head:refs/merge-requests/*/head']
    end

    def self.new_client_for(project, token: nil, host: nil, parallel: true)
      token_to_use = token || project.import_data&.credentials&.fetch(:user)
      Client.new(
        token_to_use,
        host: self.formatted_import_url(project),
        parallel: parallel
      )
    end

    # Returns the ID of the ghost user.
    def self.ghost_user_id
      key = 'github-import/ghost-user-id'

      Gitlab::Cache::Import::Caching.read_integer(key) || Gitlab::Cache::Import::Caching.write(key, User.select(:id).ghost.id)
    end

    # Get formatted GitHub import URL. If github.com is in the import URL, this will return nil and octokit will use the default github.com API URL
    def self.formatted_import_url(project)
      url = URI.parse(project.import_url)

      unless url.host == 'github.com'
        url.user = nil
        url.password = nil
        url.path = "/api/v3"
        url.to_s
      end
    end
  end
end
