require 'spec_helper'

describe Projects::FeatureFlagsController do
  include Gitlab::Routing
  include FeatureFlagHelpers

  set(:project) { create(:project) }
  let(:user) { developer }
  let(:developer) { create(:user) }
  let(:reporter) { create(:user) }
  let(:feature_enabled) { true }

  before do
    project.add_developer(developer)
    project.add_reporter(reporter)

    sign_in(user)
    stub_licensed_features(feature_flags: feature_enabled)
  end

  describe 'GET index' do
    render_views

    subject { get(:index, params: view_params) }

    context 'when there is no feature flags' do
      before do
        subject
      end

      it 'renders page' do
        expect(response).to be_ok
      end
    end

    context 'for a list of feature flags' do
      let!(:feature_flags) { create_list(:operations_feature_flag, 50, project: project) }

      before do
        subject
      end

      it 'renders page' do
        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when feature is not available' do
      let(:feature_enabled) { false }

      before do
        subject
      end

      it 'shows not found' do
        expect(subject).to have_gitlab_http_status(404)
      end
    end
  end

  describe 'GET #index.json' do
    subject { get(:index, params: view_params, format: :json) }

    let!(:feature_flag_active) do
      create(:operations_feature_flag, project: project, active: true)
    end

    let!(:feature_flag_inactive) do
      create(:operations_feature_flag, project: project, active: false)
    end

    it 'returns all feature flags as json response' do
      subject

      expect(json_response['feature_flags'].count).to eq(2)
      expect(json_response['feature_flags'].first['name']).to eq(feature_flag_active.name)
      expect(json_response['feature_flags'].second['name']).to eq(feature_flag_inactive.name)
    end

    it 'returns edit path and destroy path' do
      subject

      expect(json_response['feature_flags'].first['edit_path']).not_to be_nil
      expect(json_response['feature_flags'].first['destroy_path']).not_to be_nil
    end

    it 'returns the summary of feature flags' do
      subject

      expect(json_response['count']['all']).to eq(2)
      expect(json_response['count']['enabled']).to eq(1)
      expect(json_response['count']['disabled']).to eq(1)
    end

    it 'matches json schema' do
      subject

      expect(response).to match_response_schema('feature_flags', dir: 'ee')
    end

    context 'when scope is specified' do
      let(:view_params) do
        { namespace_id: project.namespace, project_id: project, scope: scope }
      end

      context 'when scope is all' do
        let(:scope) { 'all' }

        it 'returns all feature flags' do
          subject

          expect(json_response['feature_flags'].count).to eq(2)
        end
      end

      context 'when scope is enabled' do
        let(:scope) { 'enabled' }

        it 'returns enabled feature flags' do
          subject

          expect(json_response['feature_flags'].count).to eq(1)
          expect(json_response['feature_flags'].first['active']).to be_truthy
        end
      end

      context 'when scope is disabled' do
        let(:scope) { 'disabled' }

        it 'returns disabled feature flags' do
          subject

          expect(json_response['feature_flags'].count).to eq(1)
          expect(json_response['feature_flags'].first['active']).to be_falsy
        end
      end
    end

    context 'when feature flags have additional scopes' do
      let!(:feature_flag_active_scope) do
        create(:operations_feature_flag_scope,
               feature_flag: feature_flag_active,
               environment_scope: 'production',
               active: false)
      end

      let!(:feature_flag_inactive_scope) do
        create(:operations_feature_flag_scope,
               feature_flag: feature_flag_inactive,
               environment_scope: 'staging',
               active: false)
      end

      it 'returns a correct summary' do
        subject

        expect(json_response['count']['all']).to eq(2)
        expect(json_response['count']['enabled']).to eq(1)
        expect(json_response['count']['disabled']).to eq(1)
      end

      it 'recongnizes feature flag 1 as active' do
        subject

        expect(json_response['feature_flags'].first['active']).to be_truthy
      end

      it 'recongnizes feature flag 2 as inactive' do
        subject

        expect(json_response['feature_flags'].second['active']).to be_falsy
      end

      it 'has ordered scopes' do
        subject

        expect(json_response['feature_flags'][0]['scopes'][0]['id'])
          .to be < json_response['feature_flags'][0]['scopes'][1]['id']
        expect(json_response['feature_flags'][1]['scopes'][0]['id'])
          .to be < json_response['feature_flags'][1]['scopes'][1]['id']
      end

      it 'does not have N+1 problem' do
        recorded = ActiveRecord::QueryRecorder.new { subject }

        related_count = recorded.log
          .select { |query| query.include?('operations_feature_flag') }.count

        expect(related_count).to be_within(5).of(2)
      end
    end
  end

  describe 'GET new' do
    render_views

    subject { get(:new, params: view_params) }

    it 'renders the form' do
      subject

      expect(response).to be_ok
    end
  end

  describe 'GET #show.json' do
    subject { get(:show, params: params, format: :json) }

    let!(:feature_flag) do
      create(:operations_feature_flag, project: project)
    end

    let(:params) do
      {
        namespace_id: project.namespace,
        project_id: project,
        id: feature_flag.id
      }
    end

    it 'returns all feature flags as json response' do
      subject

      expect(json_response['name']).to eq(feature_flag.name)
      expect(json_response['active']).to eq(feature_flag.active)
    end

    it 'matches json schema' do
      subject

      expect(response).to match_response_schema('feature_flag', dir: 'ee')
    end

    context 'when feature flag is not found' do
      let!(:feature_flag) { }

      let(:params) do
        {
          namespace_id: project.namespace,
          project_id: project,
          id: 1
        }
      end

      it 'returns 404' do
        subject

        expect(response).to have_gitlab_http_status(404)
      end
    end

    context 'when user is reporter' do
      let(:user) { reporter }

      it 'returns 404' do
        subject

        expect(response).to have_gitlab_http_status(404)
      end
    end

    context 'when feature flags have additional scopes' do
      context 'when there is at least one active scope' do
        let!(:feature_flag) do
          create(:operations_feature_flag, project: project, active: false)
        end

        let!(:feature_flag_scope_production) do
          create(:operations_feature_flag_scope,
                feature_flag: feature_flag,
                environment_scope: 'review/*',
                active: true)
        end

        it 'recongnizes the feature flag as active' do
          subject

          expect(json_response['active']).to be_truthy
        end
      end

      context 'when all scopes are inactive' do
        let!(:feature_flag) do
          create(:operations_feature_flag, project: project, active: false)
        end

        let!(:feature_flag_scope_production) do
          create(:operations_feature_flag_scope,
                feature_flag: feature_flag,
                environment_scope: 'production',
                active: false)
        end

        it 'recongnizes the feature flag as inactive' do
          subject

          expect(json_response['active']).to be_falsy
        end
      end
    end
  end

  describe 'POST create.json' do
    subject { post(:create, params: params, format: :json) }

    let(:params) do
      {
        namespace_id: project.namespace,
        project_id: project,
        operations_feature_flag: {
          name: 'my_feature_flag',
          active: true
        }
      }
    end

    it 'returns 200' do
      subject

      expect(response).to have_gitlab_http_status(200)
    end

    it 'creates a new feature flag' do
      subject

      expect(json_response['name']).to eq('my_feature_flag')
      expect(json_response['active']).to be_truthy
    end

    it 'creates a default scope' do
      subject

      expect(json_response['scopes'].count).to eq(1)
      expect(json_response['scopes'].first['environment_scope']).to eq('*')
      expect(json_response['scopes'].first['active']).to be_truthy
    end

    it 'matches json schema' do
      subject

      expect(response).to match_response_schema('feature_flag', dir: 'ee')
    end

    context 'when the same named feature flag has already existed' do
      before do
        create(:operations_feature_flag, name: 'my_feature_flag', project: project)
      end

      it 'returns 400' do
        subject

        expect(response).to have_gitlab_http_status(400)
      end

      it 'returns an error message' do
        subject

        expect(json_response['message']).to include('Name has already been taken')
      end
    end

    context 'when user is reporter' do
      let(:user) { reporter }

      it 'returns 404' do
        subject

        expect(response).to have_gitlab_http_status(404)
      end
    end

    context 'when creates additional scope' do
      let(:params) do
        view_params.merge({
          operations_feature_flag: {
            name: 'my_feature_flag',
            active: true,
            scopes_attributes: [{ environment_scope: '*', active: true },
                                { environment_scope: 'production', active: false }]
          }
        })
      end

      it 'creates feature flag scopes successfully' do
        expect { subject }.to change { Operations::FeatureFlagScope.count }.by(2)

        expect(response).to have_gitlab_http_status(200)
      end

      it 'creates feature flag scopes in a correct order' do
        subject

        expect(json_response['scopes'].first['environment_scope']).to eq('*')
        expect(json_response['scopes'].second['environment_scope']).to eq('production')
      end

      context 'when default scope is not placed first' do
        let(:params) do
          view_params.merge({
            operations_feature_flag: {
              name: 'my_feature_flag',
              active: true,
              scopes_attributes: [{ environment_scope: 'production', active: false },
                                  { environment_scope: '*', active: true }]
            }
          })
        end

        it 'returns 400' do
          subject

          expect(response).to have_gitlab_http_status(400)
          expect(json_response['message'])
            .to include('Default scope has to be the first element')
        end
      end
    end

    context 'when creates additional scope with a percentage rollout' do
      let(:params) do
        view_params.merge({
          operations_feature_flag: {
            name: 'my_feature_flag',
            active: true,
            scopes_attributes: [{ environment_scope: '*', active: true },
                                { environment_scope: 'production', active: false,
                                  strategy_attributes: { parameters: { percentage: "42" } } }]
          }
        })
      end

      it 'creates a strategy for the scope' do
        expect { subject }.to change { Operations::FeatureFlagStrategy.count }.by(1)

        default_strategy_json = json_response['scopes'].first['strategy']
        production_strategy_json = json_response['scopes'].second['strategy']
        expect(response).to have_gitlab_http_status(:ok)
        expect(default_strategy_json).to be_nil
        expect(production_strategy_json['name']).to eq('gradualRolloutUserId')
        expect(production_strategy_json['parameters']).to eq({ "groupId" => "default", "percentage" => "42" })
      end
    end
  end

  describe 'DELETE destroy.json' do
    subject { delete(:destroy, params: params, format: :json) }

    let!(:feature_flag) { create(:operations_feature_flag, project: project) }

    let(:params) do
      {
        namespace_id: project.namespace,
        project_id: project,
        id: feature_flag.id
      }
    end

    it 'returns 200' do
      subject

      expect(response).to have_gitlab_http_status(200)
    end

    it 'deletes one feature flag' do
      expect { subject }.to change { Operations::FeatureFlag.count }.by(-1)
    end

    it 'destroys the default scope' do
      expect { subject }.to change { Operations::FeatureFlagScope.count }.by(-1)
    end

    it 'matches json schema' do
      subject

      expect(response).to match_response_schema('feature_flag', dir: 'ee')
    end

    context 'when user is reporter' do
      let(:user) { reporter }

      it 'returns 404' do
        subject

        expect(response).to have_gitlab_http_status(404)
      end
    end

    context 'when there is an additional scope' do
      let!(:scope) { create_scope(feature_flag, 'production', false) }

      it 'destroys the default scope and production scope' do
        expect { subject }.to change { Operations::FeatureFlagScope.count }.by(-2)
      end
    end

    context 'when there is an additional scope with a strategy' do
      let!(:scope) { create_scope(feature_flag, 'production', false) }
      let!(:strategy) { create(:operations_feature_flag_strategy, feature_flag_scope: scope) }

      it 'destroys both scopes and the strategy' do
        subject

        expect(Operations::FeatureFlagScope.count).to eq(0)
        expect(Operations::FeatureFlagStrategy.count).to eq(0)
      end
    end
  end

  describe 'PUT update.json' do
    subject { put(:update, params: params, format: :json) }

    let!(:feature_flag) do
      create(:operations_feature_flag,
        name: 'ci_live_trace',
        active: true,
        project: project)
    end

    let(:params) do
      {
        namespace_id: project.namespace,
        project_id: project,
        id: feature_flag.id,
        operations_feature_flag: {
          name: 'ci_new_live_trace'
        }
      }
    end

    it 'returns 200' do
      subject

      expect(response).to have_gitlab_http_status(200)
    end

    it 'updates the name of the feature flag name' do
      subject

      expect(json_response['name']).to eq('ci_new_live_trace')
    end

    it 'matches json schema' do
      subject

      expect(response).to match_response_schema('feature_flag', dir: 'ee')
    end

    context 'when updates active' do
      let(:params) do
        {
          namespace_id: project.namespace,
          project_id: project,
          id: feature_flag.id,
          operations_feature_flag: {
            active: false
          }
        }
      end

      it 'updates active from true to false' do
        expect { subject }
          .to change { feature_flag.reload.active }.from(true).to(false)
      end

      it "updates default scope's active too" do
        expect { subject }
          .to change { feature_flag.default_scope.reload.active }.from(true).to(false)
      end
    end

    context 'when user is reporter' do
      let(:user) { reporter }

      it 'returns 404' do
        subject

        expect(response).to have_gitlab_http_status(404)
      end
    end

    context "when creates an additional scope for production environment" do
      let(:params) do
        {
          namespace_id: project.namespace,
          project_id: project,
          id: feature_flag.id,
          operations_feature_flag: {
            scopes_attributes: [{ environment_scope: 'production', active: false }]
          }
        }
      end

      it 'creates a production scope' do
        expect { subject }.to change { feature_flag.reload.scopes.count }.by(1)

        expect(json_response['scopes'].last['environment_scope']).to eq('production')
        expect(json_response['scopes'].last['active']).to be_falsy
      end
    end

    context "when creates a default scope" do
      let(:params) do
        {
          namespace_id: project.namespace,
          project_id: project,
          id: feature_flag.id,
          operations_feature_flag: {
            scopes_attributes: [{ environment_scope: '*', active: false }]
          }
        }
      end

      it 'returns 400' do
        subject

        expect(response).to have_gitlab_http_status(400)
      end
    end

    context "when updates a default scope's active value" do
      let(:params) do
        {
          namespace_id: project.namespace,
          project_id: project,
          id: feature_flag.id,
          operations_feature_flag: {
            scopes_attributes: [
              {
                id: feature_flag.default_scope.id,
                environment_scope: '*',
                active: false
              }
            ]
          }
        }
      end

      it "updates successfully" do
        subject

        expect(json_response['scopes'].first['environment_scope']).to eq('*')
        expect(json_response['scopes'].first['active']).to be_falsy
      end
    end

    context "when changes default scope's spec" do
      let(:params) do
        {
          namespace_id: project.namespace,
          project_id: project,
          id: feature_flag.id,
          operations_feature_flag: {
            scopes_attributes: [
              {
                id: feature_flag.default_scope.id,
                environment_scope: 'review/*'
              }
            ]
          }
        }
      end

      it 'returns 400' do
        subject

        expect(response).to have_gitlab_http_status(400)
      end
    end

    context "when destroys the default scope" do
      let(:params) do
        {
          namespace_id: project.namespace,
          project_id: project,
          id: feature_flag.id,
          operations_feature_flag: {
            scopes_attributes: [
              {
                id: feature_flag.default_scope.id,
                _destroy: 1
              }
            ]
          }
        }
      end

      it 'raises an error' do
        expect { subject }.to raise_error(ActiveRecord::ReadOnlyRecord)
      end
    end

    context "when destroys a production scope" do
      let!(:production_scope) { create_scope(feature_flag, 'production', true) }
      let(:params) do
        {
          namespace_id: project.namespace,
          project_id: project,
          id: feature_flag.id,
          operations_feature_flag: {
            scopes_attributes: [
              {
                id: production_scope.id,
                _destroy: 1
              }
            ]
          }
        }
      end

      it 'destroys successfully' do
        subject

        scopes = json_response['scopes']
        expect(scopes.any? { |scope| scope['environment_scope'] == 'production' })
          .to be_falsy
      end
    end

    context "updating the strategy" do
      let!(:production_scope) { create_scope(feature_flag, 'production', true) }

      def request_params(strategy_attributes = nil)
        {
          namespace_id: project.namespace,
          project_id: project,
          id: feature_flag.id,
          operations_feature_flag: {
            scopes_attributes: [
              {
                id: production_scope.id,
                strategy_attributes: strategy_attributes
              }
            ]
          }
        }
      end

      context 'when there is no strategy' do
        it 'does not create a strategy when there are no strategy_attributes' do
          params = request_params

          put(:update, params: params, format: :json)

          production_scope = json_response['scopes'].select do |s|
            s['environment_scope'] == 'production'
          end.first
          expect(response).to have_gitlab_http_status(:ok)
          expect(production_scope['strategy']).to be_nil
          expect(Operations::FeatureFlagStrategy.count).to eq(0)
        end

        it 'creates a default strategy when the percentage is an empty string' do
          params = request_params({ parameters: { percentage: "" } })

          put(:update, params: params, format: :json)

          production_scope = json_response['scopes'].select do |s|
            s['environment_scope'] == 'production'
          end.first
          strategy_json = production_scope['strategy']
          expect(response).to have_gitlab_http_status(:ok)
          expect(strategy_json['name']).to eq('default')
          expect(strategy_json['parameters']).to eq({})
          expect(Operations::FeatureFlagStrategy.count).to eq(1)
        end

        it 'creates a gradualRolloutUserId strategy when the percentage is a number' do
          params = request_params({ parameters: { percentage: "70" } })

          put(:update, params: params, format: :json)

          production_scope = json_response['scopes'].select do |s|
            s['environment_scope'] == 'production'
          end.first
          strategy_json = production_scope['strategy']
          expect(response).to have_gitlab_http_status(:ok)
          expect(strategy_json['name']).to eq('gradualRolloutUserId')
          expect(strategy_json['parameters']).to eq({ "percentage" => "70", "groupId" => "default" })
          expect(Operations::FeatureFlagStrategy.count).to eq(1)
        end
      end

      context 'when there is a default strategy' do
        let!(:strategy) do
          create(:operations_feature_flag_strategy,
                 feature_flag_scope: production_scope,
                 name: "default",
                 parameters: {})
        end

        it 'does not change the strategy when there are no strategy_attributes' do
          params = request_params

          put(:update, params: params, format: :json)

          production_scope = json_response['scopes'].select do |s|
            s['environment_scope'] == 'production'
          end.first
          strategy_json = production_scope['strategy']
          expect(response).to have_gitlab_http_status(:ok)
          expect(strategy_json['id']).to eq(strategy.id)
          expect(strategy_json['name']).to eq('default')
          expect(strategy_json['parameters']).to eq({})
          expect(Operations::FeatureFlagStrategy.count).to eq(1)
        end

        it 'does not change the strategy when the percentage is an empty string' do
          params = request_params({ id: strategy.id, parameters: { percentage: "" } })

          put(:update, params: params, format: :json)

          production_scope = json_response['scopes'].select do |s|
            s['environment_scope'] == 'production'
          end.first
          strategy_json = production_scope['strategy']
          expect(response).to have_gitlab_http_status(:ok)
          expect(strategy_json['id']).to eq(strategy.id)
          expect(strategy_json['name']).to eq('default')
          expect(strategy_json['parameters']).to eq({})
          expect(Operations::FeatureFlagStrategy.count).to eq(1)
        end

        it 'changes the strategy to gradualRolloutUserId when the percentage is a number' do
          params = request_params({ id: strategy.id, parameters: { percentage: "5" } })

          put(:update, params: params, format: :json)

          production_scope = json_response['scopes'].select do |s|
            s['environment_scope'] == 'production'
          end.first
          strategy_json = production_scope['strategy']
          expect(response).to have_gitlab_http_status(:ok)
          expect(strategy_json['id']).to eq(strategy.id)
          expect(strategy_json['name']).to eq('gradualRolloutUserId')
          expect(strategy_json['parameters']).to eq({ "groupId" => "default", "percentage" => "5" })
          expect(Operations::FeatureFlagStrategy.count).to eq(1)
        end
      end

      context 'when there is a gradualRolloutUserId strategy' do
        let!(:strategy) do
          create(:operations_feature_flag_strategy,
                 feature_flag_scope: production_scope,
                 name: "gradualRolloutUserId",
                 parameters: { groupId: 'default', percentage: "80" })
        end

        it 'does not change the strategy when there are no strategy_attributes' do
          params = request_params

          put(:update, params: params, format: :json)

          production_scope = json_response['scopes'].select do |s|
            s['environment_scope'] == 'production'
          end.first
          strategy_json = production_scope['strategy']
          expect(response).to have_gitlab_http_status(:ok)
          expect(strategy_json['id']).to eq(strategy.id)
          expect(strategy_json['name']).to eq('gradualRolloutUserId')
          expect(strategy_json['parameters']).to eq({ "percentage" => "80", "groupId" => "default" })
          expect(Operations::FeatureFlagStrategy.count).to eq(1)
        end

        it 'changes the strategy to default when the percentage is an empty string' do
          params = request_params({ id: strategy.id, parameters: { percentage: "" } })

          put(:update, params: params, format: :json)

          production_scope = json_response['scopes'].select do |s|
            s['environment_scope'] == 'production'
          end.first
          strategy_json = production_scope['strategy']
          expect(response).to have_gitlab_http_status(:ok)
          expect(strategy_json['id']).to eq(strategy.id)
          expect(strategy_json['name']).to eq('default')
          expect(strategy_json['parameters']).to eq({})
          expect(Operations::FeatureFlagStrategy.count).to eq(1)
        end

        it 'updates the strategy when the percentage is a number' do
          params = request_params({ id: strategy.id, parameters: { percentage: "50" } })

          put(:update, params: params, format: :json)

          production_scope = json_response['scopes'].select do |s|
            s['environment_scope'] == 'production'
          end.first
          strategy_json = production_scope['strategy']
          expect(response).to have_gitlab_http_status(:ok)
          expect(strategy_json['id']).to eq(strategy.id)
          expect(strategy_json['name']).to eq('gradualRolloutUserId')
          expect(strategy_json['parameters']).to eq({ "percentage" => "50", "groupId" => "default" })
          expect(Operations::FeatureFlagStrategy.count).to eq(1)
        end
      end

      context 'when there is a strategy and the request has parameters without an id' do
        let!(:strategy) do
          create(:operations_feature_flag_strategy,
                 feature_flag_scope: production_scope,
                 name: "default",
                 parameters: {})
        end

        it 'does not orphan a record' do
          params = request_params({ parameters: { percentage: "15" } })

          put(:update, params: params, format: :json)

          production_scope = json_response['scopes'].select do |s|
            s['environment_scope'] == 'production'
          end.first
          strategy_json = production_scope['strategy']
          expect(response).to have_gitlab_http_status(:ok)
          expect(strategy_json['id']).not_to eq(strategy.id)
          expect(strategy_json['name']).to eq('gradualRolloutUserId')
          expect(strategy_json['parameters']).to eq({ "groupId" => "default", "percentage" => "15" })
          expect(Operations::FeatureFlagStrategy.count).to eq(1)
        end
      end
    end
  end

  private

  def view_params
    { namespace_id: project.namespace, project_id: project }
  end
end
