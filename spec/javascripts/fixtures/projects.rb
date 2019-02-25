require 'spec_helper'

describe 'Projects (JavaScript fixtures)', type: :controller do
  include JavaScriptFixturesHelpers

  runners_token = 'runnerstoken:intabulasreferre'

  let(:admin) { create(:admin) }
  let(:namespace) { create(:namespace, name: 'frontend-fixtures' )}
  let(:project) { create(:project, namespace: namespace, path: 'builds-project', runners_token: runners_token) }
  let(:project_with_repo) { create(:project, :repository, description: 'Code and stuff') }
  let(:project_variable_populated) { create(:project, namespace: namespace, path: 'builds-project2', runners_token: runners_token) }

  render_views

  before(:all) do
    clean_frontend_fixtures('projects/')
  end

  before do
    # EE-specific start
    stub_licensed_features(variable_environment_scope: true)
    # EE specific end
    project.add_maintainer(admin)
    sign_in(admin)
    allow(SecureRandom).to receive(:hex).and_return('securerandomhex:thereisnospoon')
  end

  after do
    remove_repository(project)
  end

  describe ProjectsController, '(JavaScript fixtures)', type: :controller do
    it 'projects/dashboard.html.raw' do |example|
      get :show, params: {
        namespace_id: project.namespace.to_param,
        id: project
      }

      expect(response).to be_success
      store_frontend_fixture(response, example.description)
    end

    it 'projects/overview.html.raw' do |example|
      get :show, params: {
        namespace_id: project_with_repo.namespace.to_param,
        id: project_with_repo
      }

      expect(response).to be_success
      store_frontend_fixture(response, example.description)
    end

    it 'projects/edit.html.raw' do |example|
      get :edit, params: {
        namespace_id: project.namespace.to_param,
        id: project
      }

      expect(response).to be_success
      store_frontend_fixture(response, example.description)
    end
  end

  describe Projects::Settings::CiCdController, '(JavaScript fixtures)', type: :controller do
    it 'projects/ci_cd_settings.html.raw' do |example|
      get :show, params: {
        namespace_id: project.namespace.to_param,
        project_id: project
      }

      expect(response).to be_success
      store_frontend_fixture(response, example.description)
    end

    it 'projects/ci_cd_settings_with_variables.html.raw' do |example|
      create(:ci_variable, project: project_variable_populated)
      create(:ci_variable, project: project_variable_populated)

      get :show, params: {
        namespace_id: project_variable_populated.namespace.to_param,
        project_id: project_variable_populated
      }

      expect(response).to be_success
      store_frontend_fixture(response, example.description)
    end
  end
end
