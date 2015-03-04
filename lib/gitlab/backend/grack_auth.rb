require_relative 'shell_env'

module Grack
  class Auth < Rack::Auth::Basic

    attr_accessor :user, :project, :env

    def call(env)
      @env = env
      @request = Rack::Request.new(env)
      @auth = Request.new(env)

      @gitlab_ci = false

      # Need this patch due to the rails mount
      # Need this if under RELATIVE_URL_ROOT
      unless Gitlab.config.gitlab.relative_url_root.empty?
        # If website is mounted using relative_url_root need to remove it first
        @env['PATH_INFO'] = @request.path.sub(Gitlab.config.gitlab.relative_url_root,'')
      else
        @env['PATH_INFO'] = @request.path
      end

      @env['SCRIPT_NAME'] = ""

      auth!

      if project && authorized_request?
        @app.call(env)
      elsif @user.nil? && !@gitlab_ci
        unauthorized
      else
        render_not_found
      end
    end

    private

    def auth!
      return unless @auth.provided?

      return bad_request unless @auth.basic?

      # Authentication with username and password
      login, password = @auth.credentials

      # Allow authentication for GitLab CI service
      # if valid token passed
      if gitlab_ci_request?(login, password)
        @gitlab_ci = true
        return
      end

      @user = authenticate_user(login, password)

      if @user
        Gitlab::ShellEnv.set_env(@user)
        @env['REMOTE_USER'] = @auth.username
      end
    end

    def gitlab_ci_request?(login, password)
      if login == "gitlab-ci-token" && project && project.gitlab_ci?
        token = project.gitlab_ci_service.token

        if token.present? && token == password && git_cmd == 'git-upload-pack'
          return true
        end
      end

      false
    end

    def oauth_access_token_check(login, password)
      if login == "oauth2" && git_cmd == 'git-upload-pack' && password.present?
        token = Doorkeeper::AccessToken.by_token(password)
        token && token.accessible? && User.find_by(id: token.resource_owner_id)
      end
    end

    def authenticate_user(login, password)
      user = Gitlab::Auth.new.find(login, password)

      unless user
        user = oauth_access_token_check(login, password)
      end

      return user if user.present?

      # At this point, we know the credentials were wrong. We let Rack::Attack
      # know there was a failed authentication attempt from this IP. This
      # information is stored in the Rails cache (Redis) and will be used by
      # the Rack::Attack middleware to decide whether to block requests from
      # this IP.
      config = Gitlab.config.rack_attack.git_basic_auth
      Rack::Attack::Allow2Ban.filter(@request.ip, config) do
        # Unless the IP is whitelisted, return true so that Allow2Ban
        # increments the counter (stored in Rails.cache) for the IP
        if config.ip_whitelist.include?(@request.ip)
          false
        else
          true
        end
      end

      nil # No user was found
    end

    def authorized_request?
      return true if @gitlab_ci

      case git_cmd
      when *Gitlab::GitAccess::DOWNLOAD_COMMANDS
        if user
          Gitlab::GitAccess.new.download_access_check(user, project).allowed?
        elsif project.public?
          # Allow clone/fetch for public projects
          true
        else
          false
        end
      when *Gitlab::GitAccess::PUSH_COMMANDS
        if user
          # Skip user authorization on upload request.
          # It will be done by the pre-receive hook in the repository.
          true
        else
          false
        end
      else
        false
      end
    end

    def git_cmd
      if @request.get?
        @request.params['service']
      elsif @request.post?
        File.basename(@request.path)
      else
        nil
      end
    end

    def project
      return @project if defined?(@project)

      @project = project_by_path(@request.path_info)
    end

    def project_by_path(path)
      if m = /^([\w\.\/-]+)\.git/.match(path).to_a
        path_with_namespace = m.last
        path_with_namespace.gsub!(/\.wiki$/, '')

        Project.find_with_namespace(path_with_namespace)
      end
    end

    def render_not_found
      [404, { "Content-Type" => "text/plain" }, ["Not Found"]]
    end
  end
end
