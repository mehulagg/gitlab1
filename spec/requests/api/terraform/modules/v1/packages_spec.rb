# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Terraform::Modules::V1::Packages do
  include PackagesManagerApiSpecHelpers
  include WorkhorseHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:personal_access_token) { create(:personal_access_token) }
  let_it_be(:user) { personal_access_token.user }
  let_it_be(:job) { create(:ci_build, :running, user: user) }
  let_it_be(:deploy_token) { create(:deploy_token, read_package_registry: true, write_package_registry: true) }
  let_it_be(:project_deploy_token) { create(:project_deploy_token, deploy_token: deploy_token, project: project) }
  let_it_be(:headers) { {} }

  let(:tokens) do
    {
      personal_access_token: personal_access_token.token,
      deploy_token: deploy_token.token,
      job_token: job.token
    }
  end

  describe 'PUT /api/v4/projects/:project_id/packages/terraform/modules/:module_name/:module_system/:module_version/file/authorize' do
    include_context 'workhorse headers'

    let(:url) { api("/projects/#{project.id}/packages/terraform/modules/mymodule/mysystem/1.0.0/file/authorize") }
    let(:headers) { {} }

    subject { put(url, headers: headers) }

    context 'with valid project' do
      where(:visibility, :user_role, :member, :token_header, :token_type, :valid_token, :shared_examples_name, :expected_status) do
        :public  | :developer  | true  | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'process terraform module workhorse authorization' | :success
        :public  | :guest      | true  | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'rejects terraform module packages access'         | :forbidden
        :public  | :developer  | true  | 'PRIVATE-TOKEN' | :personal_access_token | false | 'rejects terraform module packages access'         | :unauthorized
        :public  | :guest      | true  | 'PRIVATE-TOKEN' | :personal_access_token | false | 'rejects terraform module packages access'         | :unauthorized
        :public  | :developer  | false | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'rejects terraform module packages access'         | :forbidden
        :public  | :guest      | false | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'rejects terraform module packages access'         | :forbidden
        :public  | :developer  | false | 'PRIVATE-TOKEN' | :personal_access_token | false | 'rejects terraform module packages access'         | :unauthorized
        :public  | :guest      | false | 'PRIVATE-TOKEN' | :personal_access_token | false | 'rejects terraform module packages access'         | :unauthorized
        :public  | :anonymous  | false | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'rejects terraform module packages access'         | :unauthorized
        :private | :developer  | true  | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'process terraform module workhorse authorization' | :success
        :private | :guest      | true  | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'rejects terraform module packages access'         | :forbidden
        :private | :developer  | true  | 'PRIVATE-TOKEN' | :personal_access_token | false | 'rejects terraform module packages access'         | :unauthorized
        :private | :guest      | true  | 'PRIVATE-TOKEN' | :personal_access_token | false | 'rejects terraform module packages access'         | :unauthorized
        :private | :developer  | false | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'rejects terraform module packages access'         | :not_found
        :private | :guest      | false | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'rejects terraform module packages access'         | :not_found
        :private | :developer  | false | 'PRIVATE-TOKEN' | :personal_access_token | false | 'rejects terraform module packages access'         | :unauthorized
        :private | :guest      | false | 'PRIVATE-TOKEN' | :personal_access_token | false | 'rejects terraform module packages access'         | :unauthorized
        :private | :anonymous  | false | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'rejects terraform module packages access'         | :unauthorized
        :public  | :developer  | true  | 'JOB-TOKEN'     | :job_token             | true  | 'process terraform module workhorse authorization' | :success
        :public  | :guest      | true  | 'JOB-TOKEN'     | :job_token             | true  | 'rejects terraform module packages access'         | :forbidden
        :public  | :developer  | true  | 'JOB-TOKEN'     | :job_token             | false | 'rejects terraform module packages access'         | :unauthorized
        :public  | :guest      | true  | 'JOB-TOKEN'     | :job_token             | false | 'rejects terraform module packages access'         | :unauthorized
        :public  | :developer  | false | 'JOB-TOKEN'     | :job_token             | true  | 'rejects terraform module packages access'         | :forbidden
        :public  | :guest      | false | 'JOB-TOKEN'     | :job_token             | true  | 'rejects terraform module packages access'         | :forbidden
        :public  | :developer  | false | 'JOB-TOKEN'     | :job_token             | false | 'rejects terraform module packages access'         | :unauthorized
        :public  | :guest      | false | 'JOB-TOKEN'     | :job_token             | false | 'rejects terraform module packages access'         | :unauthorized
        :private | :developer  | true  | 'JOB-TOKEN'     | :job_token             | true  | 'process terraform module workhorse authorization' | :success
        :private | :guest      | true  | 'JOB-TOKEN'     | :job_token             | true  | 'rejects terraform module packages access'         | :forbidden
        :private | :developer  | true  | 'JOB-TOKEN'     | :job_token             | false | 'rejects terraform module packages access'         | :unauthorized
        :private | :guest      | true  | 'JOB-TOKEN'     | :job_token             | false | 'rejects terraform module packages access'         | :unauthorized
        :private | :developer  | false | 'JOB-TOKEN'     | :job_token             | true  | 'rejects terraform module packages access'         | :not_found
        :private | :guest      | false | 'JOB-TOKEN'     | :job_token             | true  | 'rejects terraform module packages access'         | :not_found
        :private | :developer  | false | 'JOB-TOKEN'     | :job_token             | false | 'rejects terraform module packages access'         | :unauthorized
        :private | :guest      | false | 'JOB-TOKEN'     | :job_token             | false | 'rejects terraform module packages access'         | :unauthorized
        :public  | :developer  | true  | 'DEPLOY-TOKEN'  | :deploy_token          | true  | 'process terraform module workhorse authorization' | :success
        :public  | :developer  | true  | 'DEPLOY-TOKEN'  | :deploy_token          | false | 'rejects terraform module packages access'         | :unauthorized
        :private | :developer  | true  | 'DEPLOY-TOKEN'  | :deploy_token          | true  | 'process terraform module workhorse authorization' | :success
        :private | :developer  | true  | 'DEPLOY-TOKEN'  | :deploy_token          | false | 'rejects terraform module packages access'         | :unauthorized
      end

      with_them do
        let(:token) { valid_token ? tokens[token_type] : 'invalid-token123' }
        let(:headers) { user_headers.merge(workhorse_headers) }
        let(:user_headers) { user_role == :anonymous ? {} : { token_header => token } }

        before do
          project.update!(visibility: visibility.to_s)
        end

        it_behaves_like params[:shared_examples_name], params[:user_role], params[:expected_status], params[:member]
      end
    end
  end

  describe 'PUT /api/v4/projects/:project_id/packages/terraform/modules/:module_name/:module_system/:module_version/file' do
    include_context 'workhorse headers'

    let(:url) { "/projects/#{project.id}/packages/terraform/modules/mymodule/mysystem/1.0.0/file" }

    let_it_be(:file_name) { 'module-system-v1.0.0.tgz' }
    let(:headers) { {} }
    let(:params) { { file: temp_file(file_name) } }
    let(:file_key) { :file }
    let(:send_rewritten_field) { true }

    subject do
      workhorse_finalize(
        api(url),
        method: :put,
        file_key: file_key,
        params: params,
        headers: headers,
        send_rewritten_field: send_rewritten_field
      )
    end

    context 'with valid project' do
      where(:visibility, :user_role, :member, :token_header, :token_type, :valid_token, :shared_examples_name, :expected_status) do
        :public  | :developer  | true  | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'process terraform module upload'          | :created
        :public  | :guest      | true  | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'rejects terraform module packages access' | :forbidden
        :public  | :developer  | true  | 'PRIVATE-TOKEN' | :personal_access_token | false | 'rejects terraform module packages access' | :unauthorized
        :public  | :guest      | true  | 'PRIVATE-TOKEN' | :personal_access_token | false | 'rejects terraform module packages access' | :unauthorized
        :public  | :developer  | false | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'rejects terraform module packages access' | :forbidden
        :public  | :guest      | false | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'rejects terraform module packages access' | :forbidden
        :public  | :developer  | false | 'PRIVATE-TOKEN' | :personal_access_token | false | 'rejects terraform module packages access' | :unauthorized
        :public  | :guest      | false | 'PRIVATE-TOKEN' | :personal_access_token | false | 'rejects terraform module packages access' | :unauthorized
        :public  | :anonymous  | false | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'rejects terraform module packages access' | :unauthorized
        :private | :developer  | true  | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'process terraform module upload'          | :created
        :private | :guest      | true  | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'rejects terraform module packages access' | :forbidden
        :private | :developer  | true  | 'PRIVATE-TOKEN' | :personal_access_token | false | 'rejects terraform module packages access' | :unauthorized
        :private | :guest      | true  | 'PRIVATE-TOKEN' | :personal_access_token | false | 'rejects terraform module packages access' | :unauthorized
        :private | :developer  | false | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'rejects terraform module packages access' | :not_found
        :private | :guest      | false | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'rejects terraform module packages access' | :not_found
        :private | :developer  | false | 'PRIVATE-TOKEN' | :personal_access_token | false | 'rejects terraform module packages access' | :unauthorized
        :private | :guest      | false | 'PRIVATE-TOKEN' | :personal_access_token | false | 'rejects terraform module packages access' | :unauthorized
        :private | :anonymous  | false | 'PRIVATE-TOKEN' | :personal_access_token | true  | 'rejects terraform module packages access' | :unauthorized
        :public  | :developer  | true  | 'JOB-TOKEN'     | :job_token             | true  | 'process terraform module upload'          | :created
        :public  | :guest      | true  | 'JOB-TOKEN'     | :job_token             | true  | 'rejects terraform module packages access' | :forbidden
        :public  | :developer  | true  | 'JOB-TOKEN'     | :job_token             | false | 'rejects terraform module packages access' | :unauthorized
        :public  | :guest      | true  | 'JOB-TOKEN'     | :job_token             | false | 'rejects terraform module packages access' | :unauthorized
        :public  | :developer  | false | 'JOB-TOKEN'     | :job_token             | true  | 'rejects terraform module packages access' | :forbidden
        :public  | :guest      | false | 'JOB-TOKEN'     | :job_token             | true  | 'rejects terraform module packages access' | :forbidden
        :public  | :developer  | false | 'JOB-TOKEN'     | :job_token             | false | 'rejects terraform module packages access' | :unauthorized
        :public  | :guest      | false | 'JOB-TOKEN'     | :job_token             | false | 'rejects terraform module packages access' | :unauthorized
        :private | :developer  | true  | 'JOB-TOKEN'     | :job_token             | true  | 'process terraform module upload'          | :created
        :private | :guest      | true  | 'JOB-TOKEN'     | :job_token             | true  | 'rejects terraform module packages access' | :forbidden
        :private | :developer  | true  | 'JOB-TOKEN'     | :job_token             | false | 'rejects terraform module packages access' | :unauthorized
        :private | :guest      | true  | 'JOB-TOKEN'     | :job_token             | false | 'rejects terraform module packages access' | :unauthorized
        :private | :developer  | false | 'JOB-TOKEN'     | :job_token             | true  | 'rejects terraform module packages access' | :not_found
        :private | :guest      | false | 'JOB-TOKEN'     | :job_token             | true  | 'rejects terraform module packages access' | :not_found
        :private | :developer  | false | 'JOB-TOKEN'     | :job_token             | false | 'rejects terraform module packages access' | :unauthorized
        :private | :guest      | false | 'JOB-TOKEN'     | :job_token             | false | 'rejects terraform module packages access' | :unauthorized
        :public  | :developer  | true  | 'DEPLOY-TOKEN'  | :deploy_token          | true  | 'process terraform module upload'          | :created
        :public  | :developer  | true  | 'DEPLOY-TOKEN'  | :deploy_token          | false | 'rejects terraform module packages access' | :unauthorized
        :private | :developer  | true  | 'DEPLOY-TOKEN'  | :deploy_token          | true  | 'process terraform module upload'          | :created
        :private | :developer  | true  | 'DEPLOY-TOKEN'  | :deploy_token          | false | 'rejects terraform module packages access' | :unauthorized
      end

      with_them do
        let(:token) { valid_token ? tokens[token_type] : 'invalid-token123' }
        let(:user_headers) { user_role == :anonymous ? {} : { token_header => token } }
        let(:headers) { user_headers.merge(workhorse_headers) }

        before do
          project.update!(visibility: visibility.to_s)
        end

        it_behaves_like params[:shared_examples_name], params[:user_role], params[:expected_status], params[:member]
      end

      context 'failed package file save' do
        let(:user_headers) { { 'PRIVATE-TOKEN' => personal_access_token.token } }
        let(:headers) { user_headers.merge(workhorse_headers) }

        before do
          project.add_developer(user)
        end

        it 'does not create package record', :aggregate_failures do
          allow(Packages::CreatePackageFileService).to receive(:new).and_raise(StandardError)

          expect { subject }
              .to change { project.packages.count }.by(0)
              .and change { Packages::PackageFile.count }.by(0)
          expect(response).to have_gitlab_http_status(:error)
        end
      end
    end
  end
end
