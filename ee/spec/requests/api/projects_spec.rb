require 'spec_helper'

describe API::Projects do
  let(:user) { create(:user) }
  let(:project) { create(:project, namespace: user.namespace) }

  describe 'GET /projects' do
    it 'does not break on license checks' do
      enable_namespace_license_check!

      create(:project, :private, namespace: user.namespace)
      create(:project, :public, namespace: user.namespace)

      get api('/projects', user)

      expect(response).to have_gitlab_http_status(200)
    end
  end

  describe 'POST /projects' do
    context 'when importing with mirror attributes' do
      let(:import_url) { generate(:url) }
      let(:mirror_params) do
        {
          name: "Foo",
          mirror: true,
          import_url: import_url,
          mirror_trigger_builds: true
        }
      end

      it 'creates new project with pull mirroring set up' do
        post api('/projects', user), params: mirror_params

        expect(response).to have_gitlab_http_status(201)
        expect(Project.first).to have_attributes(
          mirror: true,
          import_url: import_url,
          mirror_user_id: user.id,
          mirror_trigger_builds: true
        )
      end

      it 'creates project without mirror settings when repository mirroring feature is disabled' do
        stub_licensed_features(repository_mirrors: false)

        expect { post api('/projects', user), params: mirror_params }
          .to change { Project.count }.by(1)

        expect(response).to have_gitlab_http_status(201)
        expect(Project.first).to have_attributes(
          mirror: false,
          import_url: import_url,
          mirror_user_id: nil,
          mirror_trigger_builds: false
        )
      end

      context 'when pull mirroring is not available' do
        before do
          stub_ee_application_setting(mirror_available: false)
        end

        it 'ignores the mirroring options' do
          post api('/projects', user), params: mirror_params

          expect(response).to have_gitlab_http_status(201)
          expect(Project.first.mirror?).to be false
        end

        it 'creates project with mirror settings' do
          admin = create(:admin)

          post api('/projects', admin), params: mirror_params

          expect(response).to have_gitlab_http_status(201)
          expect(Project.first).to have_attributes(
            mirror: true,
            import_url: import_url,
            mirror_user_id: admin.id,
            mirror_trigger_builds: true
          )
        end
      end
    end
  end

  describe 'PUT /projects/:id' do
    let(:project) { create(:project, namespace: user.namespace) }

    context 'when updating repository storage' do
      let(:unknown_storage) { 'new-storage' }
      let(:new_project) { create(:project, :repository, namespace: user.namespace) }

      context 'as a user' do
        it 'returns 200 but does not change repository_storage' do
          expect do
            Sidekiq::Testing.fake! do
              put(api("/projects/#{new_project.id}", user), params: { repository_storage: unknown_storage, issues_enabled: false })
            end
          end.not_to change(ProjectUpdateRepositoryStorageWorker.jobs, :size)

          expect(response).to have_gitlab_http_status(200)
          expect(json_response['issues_enabled']).to eq(false)
          expect(new_project.reload.repository.storage).to eq('default')
        end
      end

      context 'as an admin' do
        let(:admin) { create(:admin) }

        it 'returns 500 when repository storage is unknown' do
          put(api("/projects/#{new_project.id}", admin), params: { repository_storage: unknown_storage })

          expect(response).to have_gitlab_http_status(500)
          expect(json_response['message']).to match('ArgumentError')
        end

        it 'returns 200 when repository storage has changed' do
          stub_storage_settings('extra' => { 'path' => 'tmp/tests/extra_storage' })

          expect do
            Sidekiq::Testing.fake! do
              put(api("/projects/#{new_project.id}", admin), params: { repository_storage: 'extra' })
            end
          end.to change(ProjectUpdateRepositoryStorageWorker.jobs, :size).by(1)

          expect(response).to have_gitlab_http_status(200)
        end
      end
    end

    context 'when updating mirror related attributes' do
      let(:import_url) { generate(:url) }
      let(:mirror_params) do
        {
          mirror: true,
          import_url: import_url,
          mirror_user_id: user.id,
          mirror_trigger_builds: true,
          only_mirror_protected_branches: true,
          mirror_overwrites_diverged_branches: true
        }
      end

      context 'when pull mirroring is not available' do
        before do
          stub_ee_application_setting(mirror_available: false)
        end

        it 'does not update mirror related attributes' do
          put(api("/projects/#{project.id}", user), params: mirror_params)

          expect(response).to have_gitlab_http_status(200)
          expect(project.reload.mirror).to be false
        end

        it 'updates mirror related attributes when user is admin' do
          admin = create(:admin)
          mirror_params[:mirror_user_id] = admin.id
          project.add_maintainer(admin)

          expect_any_instance_of(EE::ProjectImportState).to receive(:force_import_job!).once

          put(api("/projects/#{project.id}", admin), params: mirror_params)

          expect(response).to have_gitlab_http_status(200)
          expect(project.reload).to have_attributes(
            mirror: true,
            import_url: import_url,
            mirror_user_id: admin.id,
            mirror_trigger_builds: true,
            only_mirror_protected_branches: true,
            mirror_overwrites_diverged_branches: true
          )
        end
      end

      it 'updates mirror related attributes' do
        expect_any_instance_of(EE::ProjectImportState).to receive(:force_import_job!).once

        put(api("/projects/#{project.id}", user), params: mirror_params)

        expect(response).to have_gitlab_http_status(200)
        expect(project.reload).to have_attributes(
          mirror: true,
          import_url: import_url,
          mirror_user_id: user.id,
          mirror_trigger_builds: true,
          only_mirror_protected_branches: true,
          mirror_overwrites_diverged_branches: true
        )
      end

      it 'updates project without mirror attributes when the project is unable to set up repository mirroring' do
        stub_licensed_features(repository_mirrors: false)

        put(api("/projects/#{project.id}", user), params: mirror_params)

        expect(response).to have_gitlab_http_status(200)
        expect(project.reload.mirror).to be false
      end

      it 'renders an API error when mirror user is invalid' do
        invalid_mirror_user = create(:user)
        project.add_developer(invalid_mirror_user)
        mirror_params[:mirror_user_id] = invalid_mirror_user.id

        put(api("/projects/#{project.id}", user), params: mirror_params)

        expect(response).to have_gitlab_http_status(400)
        expect(json_response["message"]["mirror_user_id"].first).to eq("is invalid")
      end

      it 'returns 403 when the user does not have access to mirror settings' do
        developer = create(:user)
        project.add_developer(developer)

        put(api("/projects/#{project.id}", developer), params: mirror_params)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    describe 'updating packages_enabled attribute' do
      it 'is enabled by default' do
        expect(project.packages_enabled).to be true
      end

      context 'packages feature is allowed by license' do
        before do
          stub_licensed_features(packages: true)
        end

        it 'disables project packages feature' do
          put(api("/projects/#{project.id}", user), params: { packages_enabled: false })

          expect(response).to have_gitlab_http_status(200)
          expect(project.reload.packages_enabled).to be false
          expect(json_response['packages_enabled']).to eq(false)
        end
      end

      context 'packages feature is not allowed by license' do
        before do
          stub_licensed_features(packages: false)
        end

        it 'disables project packages feature but does not return packages_enabled attribute' do
          put(api("/projects/#{project.id}", user), params: { packages_enabled: false })

          expect(response).to have_gitlab_http_status(200)
          expect(project.reload.packages_enabled).to be false
          expect(json_response['packages_enabled']).to be_nil
        end
      end
    end
  end

  describe 'GET /projects' do
    context 'filters by verification flags' do
      let(:project1) { create(:project, namespace: user.namespace) }

      it 'filters by :repository_verification_failed' do
        create(:repository_state, :repository_failed, project: project)
        create(:repository_state, :wiki_failed, project: project1)

        get api('/projects', user), params: { repository_checksum_failed: true }

        expect(response).to have_gitlab_http_status(200)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array
        expect(json_response.length).to eq(1)
        expect(json_response.first['id']).to eq project.id
      end

      it 'filters by :wiki_verification_failed' do
        create(:repository_state, :wiki_failed, project: project)
        create(:repository_state, :repository_failed, project: project1)

        get api('/projects', user), params: { wiki_checksum_failed: true }

        expect(response).to have_gitlab_http_status(200)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array
        expect(json_response.length).to eq(1)
        expect(json_response.first['id']).to eq project.id
      end
    end
  end

  describe 'GET /projects/:id' do
    describe 'packages_enabled attribute' do
      it 'exposed when the feature is available' do
        stub_licensed_features(packages: true)

        get api("/projects/#{project.id}", user)

        expect(json_response).to have_key 'packages_enabled'
      end

      it 'not exposed when the feature is available' do
        stub_licensed_features(packages: false)

        get api("/projects/#{project.id}", user)

        expect(json_response).not_to have_key 'packages_enabled'
      end
    end
  end
end
