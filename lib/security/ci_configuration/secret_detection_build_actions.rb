# frozen_string_literal: true

module Security
  module CiConfiguration
    class SecretDetectionBuildActions < BaseBuildActions

      private

      def update_existing_content!
        @existing_gitlab_ci_content['include'] = set_includes
      end

      def template
        return 'Auto-DevOps.gitlab-ci.yml' if @auto_devops_enabled

        'Security/Secret-Detection.gitlab-ci.yml'
      end
    end
  end
end
