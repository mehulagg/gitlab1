# frozen_string_literal: true

module API
  # Internal access API
  module Internal
    class Base < ::API::Base
      before { authenticate_by_gitlab_shell_token! }

      before do
        api_endpoint = env['api.endpoint']
        feature_category = api_endpoint.options[:for].try(:feature_category_for_app, api_endpoint).to_s

        header[Gitlab::Metrics::RequestsRackMiddleware::FEATURE_CATEGORY_HEADER] = feature_category

        Gitlab::ApplicationContext.push(
          user: -> { actor&.user },
          project: -> { project },
          caller_id: route.origin,
          feature_category: feature_category
        )
      end

      helpers ::API::Helpers::InternalHelpers

      UNKNOWN_CHECK_RESULT_ERROR = 'Unknown check result'.freeze

      VALID_PAT_SCOPES = Set.new(
        Gitlab::Auth::API_SCOPES + Gitlab::Auth::REPOSITORY_SCOPES + Gitlab::Auth::REGISTRY_SCOPES
      ).freeze

      helpers do
        def response_with_status(code: 200, success: true, message: nil, **extra_options)
          status code
          { status: success, message: message }.merge(extra_options).compact
        end

        def lfs_authentication_url(project)
          # This is a separate method so that EE can alter its behaviour more
          # easily.
          project.http_url_to_repo
        end

        def check_allowed(params)
          # This is a separate method so that EE can alter its behaviour more
          # easily.

          # Stores some Git-specific env thread-safely
          env = parse_env
          Gitlab::Git::HookEnv.set(gl_repository, env) if container

          actor.update_last_used_at!

          check_result = begin
                           access_check!(actor, params)
                         rescue Gitlab::GitAccess::ForbiddenError => e
                           # The return code needs to be 401. If we return 403
                           # the custom message we return won't be shown to the user
                           # and, instead, the default message 'GitLab: API is not accessible'
                           # will be displayed
                           return response_with_status(code: 401, success: false, message: e.message)
                         rescue Gitlab::GitAccess::TimeoutError => e
                           return response_with_status(code: 503, success: false, message: e.message)
                         rescue Gitlab::GitAccess::NotFoundError => e
                           return response_with_status(code: 404, success: false, message: e.message)
                         end

          log_user_activity(actor.user)

          case check_result
          when ::Gitlab::GitAccessResult::Success
            payload = {
              gl_repository: gl_repository,
              gl_project_path: gl_repository_path,
              gl_id: Gitlab::GlId.gl_id(actor.user),
              gl_username: actor.username,
              git_config_options: ["uploadpack.allowFilter=true",
                                   "uploadpack.allowAnySHA1InWant=true"],
              gitaly: gitaly_payload(params[:action]),
              gl_console_messages: check_result.console_messages
            }.merge!(actor.key_details)

            # Custom option for git-receive-pack command

            receive_max_input_size = Gitlab::CurrentSettings.receive_max_input_size.to_i

            if receive_max_input_size > 0
              payload[:git_config_options] << "receive.maxInputSize=#{receive_max_input_size.megabytes}"
            end

            response_with_status(**payload)
          when ::Gitlab::GitAccessResult::CustomAction
            response_with_status(code: 300, payload: check_result.payload, gl_console_messages: check_result.console_messages)
          else
            response_with_status(code: 500, success: false, message: UNKNOWN_CHECK_RESULT_ERROR)
          end
        end

        def access_check!(actor, params)
          access_checker = access_checker_for(actor, params[:protocol])
          access_checker.check(params[:action], params[:changes]).tap do |result|
            break result if @project || !repo_type.project?

            # If we have created a project directly from a git push
            # we have to assign its value to both @project and @container
            @project = @container = access_checker.container
          end
        end

        def validate_actor_key(actor, key_id)
          return 'Could not find a user without a key' unless key_id

          return 'Could not find the given key' unless actor.key

          'Could not find a user for the given key' unless actor.user
        end
      end

      namespace 'internal' do
        # Check if git command is allowed for project
        #
        # Params:
        #   key_id - ssh key id for Git over SSH
        #   user_id - user id for Git over HTTP or over SSH in keyless SSH CERT mode
        #   username - user name for Git over SSH in keyless SSH cert mode
        #   protocol - Git access protocol being used, e.g. HTTP or SSH
        #   project - project full_path (not path on disk)
        #   action - git action (git-upload-pack or git-receive-pack)
        #   changes - changes as "oldrev newrev ref", see Gitlab::ChangesList
        #   check_ip - optional, only in EE version, may limit access to
        #     group resources based on its IP restrictions
        post "/allowed" do
          # It was moved to a separate method so that EE can alter its behaviour more
          # easily.
          check_allowed(params)
        end

        post "/lfs_authenticate" do
          status 200

          unless actor.key_or_user
            raise ActiveRecord::RecordNotFound.new('User not found!')
          end

          actor.update_last_used_at!

          Gitlab::LfsToken
            .new(actor.key_or_user)
            .authentication_payload(lfs_authentication_url(project))
        end

        #
        # Get a ssh key using the fingerprint
        #
        # rubocop: disable CodeReuse/ActiveRecord
        get '/authorized_keys' do
          fingerprint = params.fetch(:fingerprint) do
            Gitlab::InsecureKeyFingerprint.new(params.fetch(:key)).fingerprint
          end
          key = Key.find_by(fingerprint: fingerprint)
          not_found!('Key') if key.nil?
          present key, with: Entities::SSHKey
        end
        # rubocop: enable CodeReuse/ActiveRecord

        #
        # Discover user by ssh key, user id or username
        #
        get '/discover' do
          present actor.user, with: Entities::UserSafe
        end

        get '/check' do
          {
            api_version: API.version,
            gitlab_version: Gitlab::VERSION,
            gitlab_rev: Gitlab.revision,
            redis: redis_ping
          }
        end

        post '/two_factor_recovery_codes' do
          status 200

          actor.update_last_used_at!
          user = actor.user

          error_message = validate_actor_key(actor, params[:key_id])

          if params[:user_id] && user.nil?
            break { success: false, message: 'Could not find the given user' }
          elsif error_message
            break { success: false, message: error_message }
          end

          break { success: false, message: 'Deploy keys cannot be used to retrieve recovery codes' } if actor.key.is_a?(DeployKey)

          unless user.two_factor_enabled?
            break { success: false, message: 'Two-factor authentication is not enabled for this user' }
          end

          codes = nil

          ::Users::UpdateService.new(current_user, user: user).execute! do |user|
            codes = user.generate_otp_backup_codes!
          end

          { success: true, recovery_codes: codes }
        end

        post '/personal_access_token' do
          status 200

          actor.update_last_used_at!
          user = actor.user

          error_message = validate_actor_key(actor, params[:key_id])

          break { success: false, message: 'Deploy keys cannot be used to create personal access tokens' } if actor.key.is_a?(DeployKey)

          if params[:user_id] && user.nil?
            break { success: false, message: 'Could not find the given user' }
          elsif error_message
            break { success: false, message: error_message }
          end

          if params[:name].blank?
            break { success: false, message: "No token name specified" }
          end

          if params[:scopes].blank?
            break { success: false, message: "No token scopes specified" }
          end

          invalid_scope = params[:scopes].find { |scope| VALID_PAT_SCOPES.exclude?(scope.to_sym) }

          if invalid_scope
            valid_scopes = VALID_PAT_SCOPES.map(&:to_s).sort
            break { success: false, message: "Invalid scope: '#{invalid_scope}'. Valid scopes are: #{valid_scopes}" }
          end

          begin
            expires_at = params[:expires_at].presence && Date.parse(params[:expires_at])
          rescue ArgumentError
            break { success: false, message: "Invalid token expiry date: '#{params[:expires_at]}'" }
          end

          result = ::PersonalAccessTokens::CreateService.new(
            user, name: params[:name], scopes: params[:scopes], expires_at: expires_at
          ).execute

          unless result.status == :success
            break { success: false, message: "Failed to create token: #{result.message}" }
          end

          access_token = result.payload[:personal_access_token]

          { success: true, token: access_token.token, scopes: access_token.scopes, expires_at: access_token.expires_at }
        end

        post '/pre_receive' do
          status 200

          reference_counter_increased = Gitlab::ReferenceCounter.new(params[:gl_repository]).increase

          { reference_counter_increased: reference_counter_increased }
        end

        post '/post_receive' do
          status 200

          response = PostReceiveService.new(actor.user, repository, project, params).execute

          present response, with: Entities::InternalPostReceive::Response
        end

        post '/two_factor_config' do
          status 200

          break { success: false } unless Feature.enabled?(:two_factor_for_cli)

          actor.update_last_used_at!
          user = actor.user

          error_message = validate_actor_key(actor, params[:key_id])

          if error_message
            { success: false, message: error_message }
          elsif actor.key.is_a?(DeployKey)
            { success: true, two_factor_required: false }
          else
            {
              success: true,
              two_factor_required: user.two_factor_enabled?
            }
          end
        end

        post '/two_factor_otp_check' do
          status 200

          break { success: false } unless Feature.enabled?(:two_factor_for_cli)

          actor.update_last_used_at!
          user = actor.user

          error_message = validate_actor_key(actor, params[:key_id])

          break { success: false, message: error_message } if error_message

          break { success: false, message: 'Deploy keys cannot be used for Two Factor' } if actor.key.is_a?(DeployKey)

          break { success: false, message: 'Two-factor authentication is not enabled for this user' } unless user.two_factor_enabled?

          otp_validation_result = ::Users::ValidateOtpService.new(user).execute(params.fetch(:otp_attempt))

          if otp_validation_result[:status] == :success
            { success: true }
          else
            { success: false, message: 'Invalid OTP' }
          end
        end
      end
    end
  end
end

API::Internal::Base.prepend_if_ee('EE::API::Internal::Base')
