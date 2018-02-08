require "spec_helper"

describe 'Git HTTP requests' do
  include GitHttpHelpers
  include WorkhorseHelpers
  include UserActivitiesHelpers

  shared_examples 'pulls require Basic HTTP Authentication' do
    context "when no credentials are provided" do
      it "responds to downloads with status 401 Unauthorized (no project existence information leak)" do
        download(path) do |response|
          expect(response).to have_gitlab_http_status(:unauthorized)
          expect(response.header['WWW-Authenticate']).to start_with('Basic ')
        end
      end
    end

    context "when only username is provided" do
      it "responds to downloads with status 401 Unauthorized" do
        download(path, user: user.username) do |response|
          expect(response).to have_gitlab_http_status(:unauthorized)
          expect(response.header['WWW-Authenticate']).to start_with('Basic ')
        end
      end
    end

    context "when username and password are provided" do
      context "when authentication fails" do
        it "responds to downloads with status 401 Unauthorized" do
          download(path, user: user.username, password: "wrong-password") do |response|
            expect(response).to have_gitlab_http_status(:unauthorized)
            expect(response.header['WWW-Authenticate']).to start_with('Basic ')
          end
        end
      end

      context "when authentication succeeds" do
        it "does not respond to downloads with status 401 Unauthorized" do
          download(path, user: user.username, password: user.password) do |response|
            expect(response).not_to have_gitlab_http_status(:unauthorized)
            expect(response.header['WWW-Authenticate']).to be_nil
          end
        end
      end
    end
  end

  shared_examples 'pushes require Basic HTTP Authentication' do
    context "when no credentials are provided" do
      it "responds to uploads with status 401 Unauthorized (no project existence information leak)" do
        upload(path) do |response|
          expect(response).to have_gitlab_http_status(:unauthorized)
          expect(response.header['WWW-Authenticate']).to start_with('Basic ')
        end
      end
    end

    context "when only username is provided" do
      it "responds to uploads with status 401 Unauthorized" do
        upload(path, user: user.username) do |response|
          expect(response).to have_gitlab_http_status(:unauthorized)
          expect(response.header['WWW-Authenticate']).to start_with('Basic ')
        end
      end
    end

    context "when username and password are provided" do
      context "when authentication fails" do
        it "responds to uploads with status 401 Unauthorized" do
          upload(path, user: user.username, password: "wrong-password") do |response|
            expect(response).to have_gitlab_http_status(:unauthorized)
            expect(response.header['WWW-Authenticate']).to start_with('Basic ')
          end
        end
      end

      context "when authentication succeeds" do
        it "does not respond to uploads with status 401 Unauthorized" do
          upload(path, user: user.username, password: user.password) do |response|
            expect(response).not_to have_gitlab_http_status(:unauthorized)
            expect(response.header['WWW-Authenticate']).to be_nil
          end
        end
      end
    end
  end

  shared_examples_for 'pulls are allowed' do
    it do
      download(path, env) do |response|
        expect(response).to have_gitlab_http_status(:ok)
        expect(response.content_type.to_s).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)
      end
    end
  end

  shared_examples_for 'pushes are allowed' do
    it do
      upload(path, env) do |response|
        expect(response).to have_gitlab_http_status(:ok)
        expect(response.content_type.to_s).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)
      end
    end
  end

  describe "User with no identities" do
    let(:user) { create(:user) }

    context "when the project doesn't exist" do
      context "when namespace doesn't exist" do
        let(:path) { 'doesnt/exist.git' }

        it_behaves_like 'pulls require Basic HTTP Authentication'
        it_behaves_like 'pushes require Basic HTTP Authentication'

        context 'when authenticated' do
          it 'rejects downloads and uploads with 404 Not Found' do
            download_or_upload(path, user: user.username, password: user.password) do |response|
              expect(response).to have_gitlab_http_status(:not_found)
            end
          end
        end
      end

      context 'when namespace exists' do
        let(:path) { "#{user.namespace.path}/new-project.git"}

        context 'when authenticated' do
          it 'creates a new project under the existing namespace' do
            expect do
              upload(path, user: user.username, password: user.password) do |response|
                expect(response).to have_gitlab_http_status(:ok)
              end
            end.to change { user.projects.count }.by(1)
          end

          it 'rejects push with 422 Unprocessable Entity when project is invalid' do
            path = "#{user.namespace.path}/new.git"

            push_get(path, user: user.username, password: user.password)

            expect(response).to have_gitlab_http_status(:unprocessable_entity)
          end
        end
      end
    end

    context "when requesting the Wiki" do
      let(:wiki) { ProjectWiki.new(project) }
      let(:path) { "/#{wiki.repository.full_path}.git" }

      context "when the project is public" do
        let(:project) { create(:project, :repository, :public, :wiki_enabled) }

        it_behaves_like 'pushes require Basic HTTP Authentication'

        context 'when unauthenticated' do
          let(:env) { {} }

          it_behaves_like 'pulls are allowed'

          it "responds to pulls with the wiki's repo" do
            download(path) do |response|
              json_body = ActiveSupport::JSON.decode(response.body)

              expect(json_body['RepoPath']).to include(wiki.repository.disk_path)
            end
          end
        end

        context 'when authenticated' do
          let(:env) { { user: user.username, password: user.password } }

          context 'and as a developer on the team' do
            before do
              project.add_developer(user)
            end

            context 'but the repo is disabled' do
              let(:project) { create(:project, :repository, :public, :repository_disabled, :wiki_enabled) }

              it_behaves_like 'pulls are allowed'
              it_behaves_like 'pushes are allowed'
            end
          end

          context 'and not on the team' do
            it_behaves_like 'pulls are allowed'

            it 'rejects pushes with 403 Forbidden' do
              upload(path, env) do |response|
                expect(response).to have_gitlab_http_status(:forbidden)
                expect(response.body).to eq(git_access_wiki_error(:write_to_wiki))
              end
            end
          end
        end
      end

      context "when the project is private" do
        let(:project) { create(:project, :repository, :private, :wiki_enabled) }

        it_behaves_like 'pulls require Basic HTTP Authentication'
        it_behaves_like 'pushes require Basic HTTP Authentication'

        context 'when authenticated' do
          context 'and as a developer on the team' do
            before do
              project.add_developer(user)
            end

            context 'but the repo is disabled' do
              let(:project) { create(:project, :repository, :private, :repository_disabled, :wiki_enabled) }

              it 'allows clones' do
                download(path, user: user.username, password: user.password) do |response|
                  expect(response).to have_gitlab_http_status(:ok)
                end
              end

              it 'pushes are allowed' do
                upload(path, user: user.username, password: user.password) do |response|
                  expect(response).to have_gitlab_http_status(:ok)
                end
              end
            end
          end

          context 'and not on the team' do
            it 'rejects clones with 404 Not Found' do
              download(path, user: user.username, password: user.password) do |response|
                expect(response).to have_gitlab_http_status(:not_found)
                expect(response.body).to eq(git_access_error(:project_not_found))
              end
            end

            it 'rejects pushes with 404 Not Found' do
              upload(path, user: user.username, password: user.password) do |response|
                expect(response).to have_gitlab_http_status(:not_found)
                expect(response.body).to eq(git_access_error(:project_not_found))
              end
            end
          end
        end
      end
    end

    context "when the project exists" do
      let(:path) { "#{project.full_path}.git" }

      context "when the project is public" do
        let(:project) { create(:project, :repository, :public) }

        it_behaves_like 'pushes require Basic HTTP Authentication'

        context 'when not authenticated' do
          let(:env) { {} }

          it_behaves_like 'pulls are allowed'
        end

        context "when authenticated" do
          let(:env) { { user: user.username, password: user.password } }

          context 'as a developer on the team' do
            before do
              project.add_developer(user)
            end

            it_behaves_like 'pulls are allowed'
            it_behaves_like 'pushes are allowed'

            context 'but git-receive-pack over HTTP is disabled in config' do
              before do
                allow(Gitlab.config.gitlab_shell).to receive(:receive_pack).and_return(false)
              end

              it 'rejects pushes with 403 Forbidden' do
                upload(path, env) do |response|
                  expect(response).to have_gitlab_http_status(:forbidden)
                  expect(response.body).to eq(git_access_error(:receive_pack_disabled_over_http))
                end
              end
            end

            context 'but git-upload-pack over HTTP is disabled in config' do
              it "rejects pushes with 403 Forbidden" do
                allow(Gitlab.config.gitlab_shell).to receive(:upload_pack).and_return(false)

                download(path, env) do |response|
                  expect(response).to have_gitlab_http_status(:forbidden)
                  expect(response.body).to eq(git_access_error(:upload_pack_disabled_over_http))
                end
              end
            end
          end

          context 'and not a member of the team' do
            it_behaves_like 'pulls are allowed'

            it 'rejects pushes with 403 Forbidden' do
              upload(path, env) do |response|
                expect(response).to have_gitlab_http_status(:forbidden)
                expect(response.body).to eq(change_access_error(:push_code))
              end
            end
          end
        end

        context 'when the request is not from gitlab-workhorse' do
          it 'raises an exception' do
            expect do
              get("/#{project.full_path}.git/info/refs?service=git-upload-pack")
            end.to raise_error(JWT::DecodeError)
          end
        end

        context 'when the repo is public' do
          context 'but the repo is disabled' do
            let(:project) { create(:project, :public, :repository, :repository_disabled) }
            let(:path) { "#{project.full_path}.git" }
            let(:env) { {} }

            it_behaves_like 'pulls require Basic HTTP Authentication'
            it_behaves_like 'pushes require Basic HTTP Authentication'
          end

          context 'but the repo is enabled' do
            let(:project) { create(:project, :public, :repository, :repository_enabled) }
            let(:path) { "#{project.full_path}.git" }
            let(:env) { {} }

            it_behaves_like 'pulls are allowed'
          end

          context 'but only project members are allowed' do
            let(:project) { create(:project, :public, :repository, :repository_private) }

            it_behaves_like 'pulls require Basic HTTP Authentication'
            it_behaves_like 'pushes require Basic HTTP Authentication'
          end
        end

        context 'and the user requests a redirected path' do
          let!(:redirect) { project.route.create_redirect('foo/bar') }
          let(:path) { "#{redirect.path}.git" }
          let(:project_moved_message) do
            <<-MSG.strip_heredoc
              Project '#{redirect.path}' was moved to '#{project.full_path}'.

              Please update your Git remote:

                git remote set-url origin #{project.http_url_to_repo} and try again.
            MSG
          end

          it 'downloads get status 404 with "project was moved" message' do
            clone_get(path, {})
            expect(response).to have_gitlab_http_status(:not_found)
            expect(response.body).to match(project_moved_message)
          end
        end
      end

      context "when the project is private" do
        let(:project) { create(:project, :repository, :private) }

        it_behaves_like 'pulls require Basic HTTP Authentication'
        it_behaves_like 'pushes require Basic HTTP Authentication'

        context "when username and password are provided" do
          let(:env) { { user: user.username, password: 'nope' } }

          context "when authentication fails" do
            context "when the user is IP banned" do
              it "responds with status 401" do
                expect(Rack::Attack::Allow2Ban).to receive(:filter).and_return(true)
                allow_any_instance_of(Rack::Request).to receive(:ip).and_return('1.2.3.4')

                clone_get(path, env)

                expect(response).to have_gitlab_http_status(:unauthorized)
              end
            end
          end

          context "when authentication succeeds" do
            let(:env) { { user: user.username, password: user.password } }

            context "when the user has access to the project" do
              before do
                project.add_master(user)
              end

              context "when the user is blocked" do
                it "rejects pulls with 401 Unauthorized" do
                  user.block
                  project.add_master(user)

                  download(path, env) do |response|
                    expect(response).to have_gitlab_http_status(:unauthorized)
                  end
                end

                it "rejects pulls with 401 Unauthorized for unknown projects (no project existence information leak)" do
                  user.block

                  download('doesnt/exist.git', env) do |response|
                    expect(response).to have_gitlab_http_status(:unauthorized)
                  end
                end
              end

              context "when the user isn't blocked" do
                it "resets the IP in Rack Attack on download" do
                  expect(Rack::Attack::Allow2Ban).to receive(:reset).twice

                  download(path, env) do
                    expect(response).to have_gitlab_http_status(:ok)
                    expect(response.content_type.to_s).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)
                  end
                end

                it "resets the IP in Rack Attack on upload" do
                  expect(Rack::Attack::Allow2Ban).to receive(:reset).twice

                  upload(path, env) do
                    expect(response).to have_gitlab_http_status(:ok)
                    expect(response.content_type.to_s).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)
                  end
                end

                it 'updates the user last activity', :clean_gitlab_redis_shared_state do
                  expect(user_activity(user)).to be_nil

                  download(path, env) do |response|
                    expect(user_activity(user)).to be_present
                  end
                end
              end

              context "when an oauth token is provided" do
                before do
                  application = Doorkeeper::Application.create!(name: "MyApp", redirect_uri: "https://app.com", owner: user)
                  @token = Doorkeeper::AccessToken.create!(application_id: application.id, resource_owner_id: user.id, scopes: "api")
                end

                let(:path) { "#{project.full_path}.git" }
                let(:env) { { user: 'oauth2', password: @token.token } }

                it_behaves_like 'pulls are allowed'
                it_behaves_like 'pushes are allowed'
              end

              context 'when user has 2FA enabled' do
                let(:user) { create(:user, :two_factor) }
                let(:access_token) { create(:personal_access_token, user: user) }
                let(:path) { "#{project.full_path}.git" }

                before do
                  project.add_master(user)
                end

                context 'when username and password are provided' do
                  it 'rejects pulls with personal access token error message' do
                    download(path, user: user.username, password: user.password) do |response|
                      expect(response).to have_gitlab_http_status(:unauthorized)
                      expect(response.body).to include('You must use a personal access token with \'api\' scope for Git over HTTP')
                    end
                  end

                  it 'rejects the push attempt with personal access token error message' do
                    upload(path, user: user.username, password: user.password) do |response|
                      expect(response).to have_gitlab_http_status(:unauthorized)
                      expect(response.body).to include('You must use a personal access token with \'api\' scope for Git over HTTP')
                    end
                  end
                end

                context 'when username and personal access token are provided' do
                  let(:env) { { user: user.username, password: access_token.token } }

                  it_behaves_like 'pulls are allowed'
                  it_behaves_like 'pushes are allowed'
                end
              end

              context 'when internal auth is disabled' do
                before do
                  allow_any_instance_of(ApplicationSetting).to receive(:password_authentication_enabled_for_git?) { false }
                end

                it 'rejects pulls with personal access token error message' do
                  download(path, user: 'foo', password: 'bar') do |response|
                    expect(response).to have_gitlab_http_status(:unauthorized)
                    expect(response.body).to include('You must use a personal access token with \'api\' scope for Git over HTTP')
                  end
                end

                it 'rejects pushes with personal access token error message' do
                  upload(path, user: 'foo', password: 'bar') do |response|
                    expect(response).to have_gitlab_http_status(:unauthorized)
                    expect(response.body).to include('You must use a personal access token with \'api\' scope for Git over HTTP')
                  end
                end

                context 'when LDAP is configured' do
                  before do
                    allow(Gitlab::LDAP::Config).to receive(:enabled?).and_return(true)
                    allow_any_instance_of(Gitlab::LDAP::Authentication)
                      .to receive(:login).and_return(nil)
                  end

                  it 'does not display the personal access token error message' do
                    upload(path, user: 'foo', password: 'bar') do |response|
                      expect(response).to have_gitlab_http_status(:unauthorized)
                      expect(response.body).not_to include('You must use a personal access token with \'api\' scope for Git over HTTP')
                    end
                  end
                end
              end

              context "when blank password attempts follow a valid login" do
                def attempt_login(include_password)
                  password = include_password ? user.password : ""
                  clone_get path, user: user.username, password: password
                  response.status
                end

                it "repeated attempts followed by successful attempt" do
                  options = Gitlab.config.rack_attack.git_basic_auth
                  maxretry = options[:maxretry] - 1
                  ip = '1.2.3.4'

                  allow_any_instance_of(Rack::Request).to receive(:ip).and_return(ip)
                  Rack::Attack::Allow2Ban.reset(ip, options)

                  maxretry.times.each do
                    expect(attempt_login(false)).to eq(401)
                  end

                  expect(attempt_login(true)).to eq(200)
                  expect(Rack::Attack::Allow2Ban.banned?(ip)).to be_falsey

                  maxretry.times.each do
                    expect(attempt_login(false)).to eq(401)
                  end

                  Rack::Attack::Allow2Ban.reset(ip, options)
                end
              end

              context 'and the user requests a redirected path' do
                let!(:redirect) { project.route.create_redirect('foo/bar') }
                let(:path) { "#{redirect.path}.git" }
                let(:project_moved_message) do
                  <<-MSG.strip_heredoc
                    Project '#{redirect.path}' was moved to '#{project.full_path}'.

                    Please update your Git remote:

                      git remote set-url origin #{project.http_url_to_repo} and try again.
                  MSG
                end

                it 'downloads get status 404 with "project was moved" message' do
                  clone_get(path, env)
                  expect(response).to have_gitlab_http_status(:not_found)
                  expect(response.body).to match(project_moved_message)
                end

                it 'uploads get status 404 with "project was moved" message' do
                  upload(path, env) do |response|
                    expect(response).to have_gitlab_http_status(:not_found)
                    expect(response.body).to match(project_moved_message)
                  end
                end
              end
            end

            context "when the user doesn't have access to the project" do
              it "pulls get status 404" do
                download(path, user: user.username, password: user.password) do |response|
                  expect(response).to have_gitlab_http_status(:not_found)
                end
              end

              it "uploads get status 404" do
                upload(path, user: user.username, password: user.password) do |response|
                  expect(response).to have_gitlab_http_status(:not_found)
                end
              end
            end
          end
        end

        context "when a gitlab ci token is provided" do
          let(:project) { create(:project, :repository) }
          let(:build) { create(:ci_build, :running) }
          let(:other_project) { create(:project) }

          before do
            build.update!(project: project) # can't associate it on factory create
          end

          context 'when build created by system is authenticated' do
            let(:path) { "#{project.full_path}.git" }
            let(:env) { { user: 'gitlab-ci-token', password: build.token } }

            it_behaves_like 'pulls are allowed'

            # A non-401 here is not an information leak since the system is
            # "authenticated" as CI using the correct token. It does not have
            # push access, so pushes should be rejected as forbidden, and giving
            # a reason is fine.
            #
            # We know for sure it is not an information leak since pulls using
            # the build token must be allowed.
            it "rejects pushes with 403 Forbidden" do
              push_get(path, env)

              expect(response).to have_gitlab_http_status(:forbidden)
              expect(response.body).to eq(git_access_error(:auth_upload))
            end

            # We are "authenticated" as CI using a valid token here. But we are
            # not authorized to see any other project, so return "not found".
            it "rejects pulls for other project with 404 Not Found" do
              clone_get("#{other_project.full_path}.git", env)

              expect(response).to have_gitlab_http_status(:not_found)
              expect(response.body).to eq(git_access_error(:project_not_found))
            end
          end

          context 'and build created by' do
            before do
              build.update(user: user)
              project.add_reporter(user)
            end

            shared_examples 'can download code only' do
              let(:path) { "#{project.full_path}.git" }
              let(:env) { { user: 'gitlab-ci-token', password: build.token } }

              it_behaves_like 'pulls are allowed'

              context 'when the repo does not exist' do
                let(:project) { create(:project) }

                it 'rejects pulls with 403 Forbidden' do
                  clone_get path, env

                  expect(response).to have_gitlab_http_status(:forbidden)
                  expect(response.body).to eq(git_access_error(:no_repo))
                end
              end

              it 'rejects pushes with 403 Forbidden' do
                push_get path, env

                expect(response).to have_gitlab_http_status(:forbidden)
                expect(response.body).to eq(git_access_error(:auth_upload))
              end
            end

            context 'administrator' do
              let(:user) { create(:admin) }

              it_behaves_like 'can download code only'

              it 'downloads from other project get status 403' do
                clone_get "#{other_project.full_path}.git", user: 'gitlab-ci-token', password: build.token

                expect(response).to have_gitlab_http_status(:forbidden)
              end
            end

            context 'regular user' do
              let(:user) { create(:user) }

              it_behaves_like 'can download code only'

              it 'downloads from other project get status 404' do
                clone_get "#{other_project.full_path}.git", user: 'gitlab-ci-token', password: build.token

                expect(response).to have_gitlab_http_status(:not_found)
              end
            end
          end
        end

        context "when Kerberos token is provided" do
          let(:env) { { spnego_request_token: 'opaque_request_token' } }

          before do
            allow_any_instance_of(Projects::GitHttpController).to receive(:allow_kerberos_spnego_auth?).and_return(true)
          end

          context "when authentication fails because of invalid Kerberos token" do
            before do
              allow_any_instance_of(Projects::GitHttpController).to receive(:spnego_credentials!).and_return(nil)
            end

            it "responds with status 401 Unauthorized" do
              download(path, env) do |response|
                expect(response).to have_gitlab_http_status(:unauthorized)
              end
            end
          end

          context "when authentication fails because of unknown Kerberos identity" do
            before do
              allow_any_instance_of(Projects::GitHttpController).to receive(:spnego_credentials!).and_return("mylogin@FOO.COM")
            end

            it "responds with status 401 Unauthorized" do
              download(path, env) do |response|
                expect(response).to have_gitlab_http_status(:unauthorized)
              end
            end
          end

          context "when authentication succeeds" do
            before do
              allow_any_instance_of(Projects::GitHttpController).to receive(:spnego_credentials!).and_return("mylogin@FOO.COM")
              user.identities.create!(provider: "kerberos", extern_uid: "mylogin@FOO.COM")
            end

            context "when the user has access to the project" do
              before do
                project.add_master(user)
              end

              context "when the user is blocked" do
                before do
                  user.block
                  project.add_master(user)
                end

                it "responds with status 403 Forbidden" do
                  download(path, env) do |response|
                    expect(response).to have_gitlab_http_status(:forbidden)
                  end
                end
              end

              context "when the user isn't blocked", :redis do
                it "responds with status 200 OK" do
                  download(path, env) do |response|
                    expect(response).to have_gitlab_http_status(:ok)
                  end
                end

                it 'updates the user last activity' do
                  download(path, env) do |_response|
                    expect(user).to have_an_activity_record
                  end
                end
              end

              it "complies with RFC4559" do
                allow_any_instance_of(Projects::GitHttpController).to receive(:spnego_response_token).and_return("opaque_response_token")
                download(path, env) do |response|
                  expect(response.headers['WWW-Authenticate'].split("\n")).to include("Negotiate #{::Base64.strict_encode64('opaque_response_token')}")
                end
              end
            end

            context "when the user doesn't have access to the project" do
              it "responds with status 404 Not Found" do
                download(path, env) do |response|
                  expect(response).to have_gitlab_http_status(:not_found)
                end
              end

              it "complies with RFC4559" do
                allow_any_instance_of(Projects::GitHttpController).to receive(:spnego_response_token).and_return("opaque_response_token")
                download(path, env) do |response|
                  expect(response.headers['WWW-Authenticate'].split("\n")).to include("Negotiate #{::Base64.strict_encode64('opaque_response_token')}")
                end
              end
            end
          end
        end

        context "when repository is above size limit" do
          let(:env) { { user: user.username, password: user.password } }

          before do
            project.add_master(user)
          end

          it 'responds with status 403 Forbidden' do
            allow_any_instance_of(EE::Project)
              .to receive(:above_size_limit?).and_return(true)

            upload(path, env) do |response|
              expect(response).to have_gitlab_http_status(:forbidden)
            end
          end
        end

        context 'when license is not provided' do
          let(:env) { { user: user.username, password: user.password } }

          before do
            allow(License).to receive(:current).and_return(nil)

            project.add_master(user)
          end

          it_behaves_like 'pulls are allowed'
          it_behaves_like 'pushes are allowed'
        end
      end

      context "when the project path doesn't end in .git" do
        let(:project) { create(:project, :repository, :public, path: 'project.git-project') }

        context "GET info/refs" do
          let(:path) { "/#{project.full_path}/info/refs" }

          context "when no params are added" do
            before do
              get path
            end

            it "redirects to the .git suffix version" do
              expect(response).to redirect_to("/#{project.full_path}.git/info/refs")
            end
          end

          context "when the upload-pack service is requested" do
            let(:params) { { service: 'git-upload-pack' } }

            before do
              get path, params
            end

            it "redirects to the .git suffix version" do
              expect(response).to redirect_to("/#{project.full_path}.git/info/refs?service=#{params[:service]}")
            end
          end

          context "when the receive-pack service is requested" do
            let(:params) { { service: 'git-receive-pack' } }

            before do
              get path, params
            end

            it "redirects to the .git suffix version" do
              expect(response).to redirect_to("/#{project.full_path}.git/info/refs?service=#{params[:service]}")
            end
          end

          context "when the params are anything else" do
            let(:params) { { service: 'git-implode-pack' } }

            before do
              get path, params
            end

            it "redirects to the sign-in page" do
              expect(response).to redirect_to(new_user_session_path)
            end
          end
        end

        context "POST git-upload-pack" do
          it "fails to find a route" do
            expect { clone_post(project.full_path) }.to raise_error(ActionController::RoutingError)
          end
        end

        context "POST git-receive-pack" do
          it "fails to find a route" do
            expect { push_post(project.full_path) }.to raise_error(ActionController::RoutingError)
          end
        end
      end

      context "retrieving an info/refs file" do
        let(:project) { create(:project, :repository, :public) }

        context "when the file exists" do
          before do
            # Provide a dummy file in its place
            allow_any_instance_of(Repository).to receive(:blob_at).and_call_original
            allow_any_instance_of(Repository).to receive(:blob_at).with('b83d6e391c22777fca1ed3012fce84f633d7fed0', 'info/refs') do
              Blob.decorate(Gitlab::Git::Blob.find(project.repository, 'master', 'bar/branch-test.txt'), project)
            end

            get "/#{project.full_path}/blob/master/info/refs"
          end

          it "returns the file" do
            expect(response).to have_gitlab_http_status(:ok)
          end
        end

        context "when the file does not exist" do
          before do
            get "/#{project.full_path}/blob/master/info/refs"
          end

          it "returns not found" do
            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end
    end
  end

  describe "User with LDAP identity" do
    let(:user) { create(:omniauth_user, extern_uid: dn) }
    let(:dn) { 'uid=john,ou=people,dc=example,dc=com' }
    let(:path) { 'doesnt/exist.git' }

    before do
      allow(Gitlab::LDAP::Config).to receive(:enabled?).and_return(true)
      allow(Gitlab::LDAP::Authentication).to receive(:login).and_return(nil)
      allow(Gitlab::LDAP::Authentication).to receive(:login).with(user.username, user.password).and_return(user)
    end

    it_behaves_like 'pulls require Basic HTTP Authentication'
    it_behaves_like 'pushes require Basic HTTP Authentication'

    context "when authentication succeeds" do
      context "when the project doesn't exist" do
        it "responds with status 404 Not Found" do
          download(path, user: user.username, password: user.password) do |response|
            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context "when the project exists" do
        let(:project) { create(:project, :repository) }
        let(:path) { "#{project.full_path}.git" }
        let(:env) { { user: user.username, password: user.password } }

        context 'and the user is on the team' do
          before do
            project.add_master(user)
          end

          it "responds with status 200" do
            clone_get(path, env) do |response|
              expect(response).to have_gitlab_http_status(200)
            end
          end

          it_behaves_like 'pulls are allowed'
          it_behaves_like 'pushes are allowed'
        end
      end
    end
  end
end
