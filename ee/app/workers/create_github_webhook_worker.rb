# frozen_string_literal: true

class CreateGithubWebhookWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker
  include GrapePathHelpers::NamedRouteMatcher

  feature_category :integrations
  worker_resource_boundary :cpu
  worker_has_external_dependencies!
  weight 2

  attr_reader :project

  def perform(project_id)
    @project = Project.find(project_id)

    create_webhook
  end

  def create_webhook
    client.octokit.create_hook(
      project.import_source,
      'web',
      {
        url: webhook_url,
        content_type: 'json',
        secret: webhook_token,
        insecure_ssl: 1
      },
      {
        events: %w[push pull_request],
        active: true
      }
    )
  end

  private

  def client
    @client ||= if Feature.enabled?(:remove_legacy_github_client)
                  Gitlab::GithubImport::Client.new(access_token)
                else
                  Gitlab::LegacyGithubImport::Client.new(access_token)
                end
  end

  def access_token
    @access_token ||= project.import_data.credentials[:user]
  end

  def webhook_url
    "#{Settings.gitlab.url}#{api_v4_projects_mirror_pull_path(id: project.id)}"
  end

  def webhook_token
    project.ensure_external_webhook_token
    project.save if project.changed?

    project.external_webhook_token
  end
end
