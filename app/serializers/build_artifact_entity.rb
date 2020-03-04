# frozen_string_literal: true

class BuildArtifactEntity < Grape::Entity
  include RequestAwareEntity
  include GitlabRoutingHelper

  expose :name do |job|
    job.name
  end

  expose :artifacts_expired?, as: :expired

  expse :artifacts_expire_at, as: :expire_at do
    job.job_artifacts_archive&.expire_at
  end

  expose :path do |job|
    fast_download_project_job_artifacts_path(project, job)
  end

  expose :keep_path, if: -> (*) { job.has_expiring_archive_artifacts? } do |job|
    fast_keep_project_job_artifacts_path(project, job)
  end

  expose :browse_path do |job|
    fast_browse_project_job_artifacts_path(project, job)
  end

  private

  alias_method :job, :object

  def project
    job.project
  end
end
