# frozen_string_literal: true

module ResourceAccessTokens
  class CreateService < BaseService
    def initialize(current_user, resource, params = {})
      @resource_type = resource.class.name.downcase
      @resource = resource
      @current_user = current_user
      @params = params.dup
    end

    def execute
      return unless feature_enabled?
      return error("User does not have permission to create #{resource_type} Access Token") unless has_permission_to_create?

      user = create_user

      return error(user.errors.full_messages.to_sentence) unless user.persisted?
      return error("Failed to provide maintainer access") unless provision_access(resource, user)

      token_response = create_personal_access_token(user)

      if token_response.success?
        success(token_response.payload[:personal_access_token])
      else
        error(token_response.message)
      end
    end

    private

    attr_reader :resource_type, :resource

    def feature_enabled?
      return false if ::Gitlab.com?

      ::Feature.enabled?(:resource_access_token, resource, default_enabled: true)
    end

    def has_permission_to_create?
      case resource_type
      when 'project'
        can?(current_user, :admin_project, resource)
      when 'group'
        can?(current_user, :admin_group, resource)
      else
        false
      end
    end

    def create_user
      # Even project maintainers can create project access tokens, which in turn
      # creates a bot user, and so it becomes necessary to  have `skip_authorization: true`
      # since someone like a project maintainer does not inherently have the ability
      # to create a new user in the system.

      Users::CreateService.new(current_user, default_user_params).execute(skip_authorization: true)
    end

    def default_user_params
      {
        name: params[:name] || "#{resource.name.to_s.humanize} bot",
        email: generate_email,
        username: generate_username,
        user_type: "#{resource_type}_bot".to_sym,
        skip_confirmation: true # Bot users should always have their emails confirmed.
      }
    end

    def generate_username
      base_username = "#{resource_type}_#{resource.id}_bot"

      uniquify.string(base_username) { |s| User.find_by_username(s) }
    end

    def generate_email
      email_pattern = "#{resource_type}#{resource.id}_bot%s@example.com"

      uniquify.string(-> (n) { Kernel.sprintf(email_pattern, n) }) do |s|
        User.find_by_email(s)
      end
    end

    def uniquify
      Uniquify.new
    end

    def create_personal_access_token(user)
      PersonalAccessTokens::CreateService.new(user, personal_access_token_params).execute
    end

    def personal_access_token_params
      {
        name: params[:name] || "#{resource_type}_bot",
        impersonation: false,
        scopes: params[:scopes] || default_scopes,
        expires_at: params[:expires_at] || nil
      }
    end

    def default_scopes
      Gitlab::Auth.resource_bot_scopes
    end

    def provision_access(resource, user)
     # resource.add_maintainer(user)
     # if resource project
      case resource_type
      when 'project'
        ProjectMember.add_user(
          project,
          user,
          :maintainer,
          current_user: current_user,
          expires_at: personal_access_token_params[:expires_at]
        )
      when 'group' # change this to GroupMember
        ProjectMember.add_user(
          project,
          user,
          :maintainer,
          current_user: current_user,
          expires_at: personal_access_token_params[:expires_at]
        )
      else # raise some error?
        return error("Failed to provision access - resource type not valid")
      end
    end

    def error(message)
      ServiceResponse.error(message: message)
    end

    def success(access_token)
      ServiceResponse.success(payload: { access_token: access_token })
    end
  end
end
