# frozen_string_literal: true

module EE
  module Gitlab
    module Auth
      module UserAuthFinders
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        JOB_TOKEN_HEADER = "HTTP_JOB_TOKEN".freeze
        JOB_TOKEN_PARAM = :job_token

        def find_user_from_bearer_token
          find_user_from_job_bearer_token ||
            find_user_from_access_token
        end

        def find_user_from_job_token
          return unless route_authentication_setting[:job_token_allowed]

          token = (params[JOB_TOKEN_PARAM] || env[JOB_TOKEN_HEADER]).to_s
          return unless token.present?

          job = ::Ci::Build.find_by_token(token)
          raise ::Gitlab::Auth::UnauthorizedError unless job

          @job_token_authentication = true # rubocop:disable Gitlab/ModuleWithInstanceVariables

          job.user
        end

        override :find_oauth_access_token
        def find_oauth_access_token
          return if scim_request?

          super
        end

        override :validate_access_token!
        def validate_access_token!(scopes: [])
          # return early if we've already authenticated via a job token
          @job_token_authentication.present? || super # rubocop:disable Gitlab/ModuleWithInstanceVariables
        end

        def scim_request?
          current_request.path.starts_with?("/api/scim/")
        end

        private

        def find_user_from_job_bearer_token
          return unless route_authentication_setting[:job_token_allowed]

          token = parsed_oauth_token
          return unless token

          job = ::Ci::Build.find_by_token(token)
          return unless job

          @job_token_authentication = true # rubocop:disable Gitlab/ModuleWithInstanceVariables

          job.user
        end
      end
    end
  end
end
