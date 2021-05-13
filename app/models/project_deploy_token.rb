# frozen_string_literal: true

class ProjectDeployToken < NamespaceShard
  belongs_to :project
  belongs_to :deploy_token, inverse_of: :project_deploy_tokens

  validates :deploy_token, presence: true
  validates :project, presence: true
  validates :deploy_token_id, uniqueness: { scope: [:project_id] }

  def has_access_to?(requested_project)
    requested_project == project
  end
end
