# frozen_string_literal: true

require 'spec_helper'

describe Projects::LogsController do
  include KubernetesHelpers

  set(:user) { create(:user) }

  let(:service) { create(:cluster_platform_kubernetes, :configured) }
  let(:cluster) { create(:cluster, :project, enabled: true, platform_kubernetes: service) }
  let(:project) { cluster.project }
  let(:environment) { create(:environment, name: 'production', project: project) }

  before do
    project.add_maintainer(user)

    sign_in(user)
  end

  describe 'GET #show' do
    let(:pod_name) { "foo" }
    let(:container) { 'container-1' }

    context "html format" do
      context 'when unlicensed' do
        before do
          stub_licensed_features(pod_logs: false)
        end

        it 'renders forbidden' do
          get :show, params: environment_params

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when licensed' do
        before do
          stub_licensed_features(pod_logs: true)
        end

        let(:empty_project) { create(:project) }

        it 'renders empty logs page if no environment exists' do
          empty_project.add_maintainer(user)
          get :show, params: { namespace_id: empty_project.namespace, project_id: empty_project }

          expect(response).to be_ok
          expect(response).to render_template 'empty_logs'
        end

        it 'renders show template' do
          get :show, params: environment_params

          expect(response).to be_ok
          expect(response).to render_template 'show'
        end
      end
    end

    context "json format" do
      let(:service_result) do
        {
          status: :success,
          logs: ['Log 1', 'Log 2', 'Log 3'],
          message: 'message',
          pods: [pod_name],
          pod_name: pod_name,
          container_name: container
        }
      end

      before do
        stub_licensed_features(pod_logs: true)

        allow_any_instance_of(PodLogsService).to receive(:execute).and_return(service_result)
      end

      shared_examples 'resource not found' do |message|
        it 'returns 400', :aggregate_failures do
          get :show, params: environment_params(pod_name: pod_name, format: :json)

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq(message)
          expect(json_response['pods']).to match_array([pod_name])
          expect(json_response['pod_name']).to eq(pod_name)
          expect(json_response['container_name']).to eq(container)
        end
      end

      it 'returns the logs for a specific pod', :aggregate_failures do
        get :show, params: environment_params(pod_name: pod_name, format: :json)

        expect(response).to have_gitlab_http_status(:success)
        expect(json_response["logs"]).to match_array(["Log 1", "Log 2", "Log 3"])
        expect(json_response["pods"]).to match_array([pod_name])
        expect(json_response['message']).to eq(service_result[:message])
        expect(json_response['pod_name']).to eq(pod_name)
        expect(json_response['container_name']).to eq(container)
      end

      it 'registers a usage of the endpoint' do
        expect(::Gitlab::UsageCounters::PodLogs).to receive(:increment).with(project.id)

        get :show, params: environment_params(pod_name: pod_name, format: :json)
      end

      context 'when kubernetes API returns error' do
        let(:service_result) do
          {
            status: :error,
            message: 'Kubernetes API returned status code: 400',
            pods: [pod_name],
            pod_name: pod_name,
            container_name: container
          }
        end

        it 'returns bad request' do
          get :show, params: environment_params(pod_name: pod_name, format: :json)

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response["logs"]).to eq(nil)
          expect(json_response["pods"]).to match_array([pod_name])
          expect(json_response["message"]).to eq('Kubernetes API returned status code: 400')
          expect(json_response['pod_name']).to eq(pod_name)
          expect(json_response['container_name']).to eq(container)
        end
      end

      context 'when pod does not exist' do
        let(:service_result) do
          {
            status: :error,
            message: 'Pod not found',
            pods: [pod_name],
            pod_name: pod_name,
            container_name: container
          }
        end

        it_behaves_like 'resource not found', 'Pod not found'
      end

      context 'when service returns error without pods, pod_name, container_name' do
        let(:service_result) do
          {
            status: :error,
            message: 'No deployment platform'
          }
        end

        it 'returns the error without pods, pod_name and container_name' do
          get :show, params: environment_params(pod_name: pod_name, format: :json)

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq('No deployment platform')
          expect(json_response.keys).to contain_exactly('message', 'status')
        end
      end

      context 'when service returns status processing' do
        let(:service_result) { { status: :processing } }

        it 'renders accepted' do
          get :show, params: environment_params(pod_name: pod_name, format: :json)

          expect(response).to have_gitlab_http_status(:accepted)
        end
      end
    end
  end

  describe 'GET #filters' do
    let(:filters) do
      {
        pods: [
          {
            name: "foo",
            namespace: "bar",
            containers: ['baz']
          },
          {
            name: "abc",
            namespace: "def",
            containers: ['ghi', 'jkl']
          }
        ]
      }
    end
    let(:pods_raw) { fixture_file('kubernetes/pods.json', dir: 'ee') }

    before do
      stub_licensed_features(pod_logs: true)
      kubeclient = instance_double(Gitlab::Kubernetes::KubeClient)
      allow_any_instance_of(Clusters::Cluster).to receive(:kubeclient).and_return(kubeclient)
      allow_any_instance_of(kubeclient).to receive(:get_pods).and_return(pods_raw)
    end

    it 'returns results' do
      get :filters, params: environment_params(format: :json)

      expect(response).to have_gitlab_http_status(:success)
      expect(json_response).to eq(filters)
    end
  end

  def environment_params(opts = {})
    opts.reverse_merge(namespace: environment.deployment_namespace,
                       namespace_id: project.namespace,
                       project_id: project,
                       cluster: cluster.name)
  end
end
