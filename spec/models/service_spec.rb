# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Service do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  describe "Associations" do
    it { is_expected.to belong_to :project }
    it { is_expected.to belong_to :group }
    it { is_expected.to have_one :service_hook }
    it { is_expected.to have_one :jira_tracker_data }
    it { is_expected.to have_one :issue_tracker_data }
  end

  describe 'validations' do
    using RSpec::Parameterized::TableSyntax

    it { is_expected.to validate_presence_of(:type) }

    where(:project_id, :group_id, :template, :instance, :valid) do
      1    | nil  | false  | false  | true
      nil  | 1    | false  | false  | true
      nil  | nil  | true   | false  | true
      nil  | nil  | false  | true   | true
      nil  | nil  | false  | false  | false
      nil  | nil  | true   | true   | false
      1    | 1    | false  | false  | false
      1    | nil  | true   | false  | false
      1    | nil  | false  | true   | false
      nil  | 1    | true   | false  | false
      nil  | 1    | false  | true   | false
    end

    with_them do
      it 'validates the service' do
        expect(build(:service, project_id: project_id, group_id: group_id, template: template, instance: instance).valid?).to eq(valid)
      end
    end

    context 'with an existing service template' do
      before do
        create(:service, :template)
      end

      it 'validates only one service template per type' do
        expect(build(:service, :template)).to be_invalid
      end
    end

    context 'with an existing instance service' do
      before do
        create(:service, :instance)
      end

      it 'validates only one service instance per type' do
        expect(build(:service, :instance)).to be_invalid
      end
    end

    it 'validates uniqueness of type and project_id on create' do
      expect(create(:service, project: project, type: 'Service')).to be_valid
      expect(build(:service, project: project, type: 'Service').valid?(:create)).to eq(false)
      expect(build(:service, project: project, type: 'Service').valid?(:update)).to eq(true)
    end

    it 'validates uniqueness of type and group_id' do
      expect(create(:service, group_id: group.id, project_id: nil, type: 'Service')).to be_valid
      expect(build(:service, group_id: group.id, project_id: nil, type: 'Service')).to be_invalid
    end
  end

  describe 'Scopes' do
    describe '.by_type' do
      let!(:service1) { create(:jira_service) }
      let!(:service2) { create(:jira_service) }
      let!(:service3) { create(:redmine_service) }

      subject { described_class.by_type(type) }

      context 'when type is "JiraService"' do
        let(:type) { 'JiraService' }

        it { is_expected.to match_array([service1, service2]) }
      end

      context 'when type is "RedmineService"' do
        let(:type) { 'RedmineService' }

        it { is_expected.to match_array([service3]) }
      end
    end

    describe '.for_group' do
      let!(:service1) { create(:jira_service, project_id: nil, group_id: group.id) }
      let!(:service2) { create(:jira_service) }

      it 'returns the right group service' do
        expect(described_class.for_group(group)).to match_array([service1])
      end
    end

    describe '.confidential_note_hooks' do
      it 'includes services where confidential_note_events is true' do
        create(:service, active: true, confidential_note_events: true)

        expect(described_class.confidential_note_hooks.count).to eq 1
      end

      it 'excludes services where confidential_note_events is false' do
        create(:service, active: true, confidential_note_events: false)

        expect(described_class.confidential_note_hooks.count).to eq 0
      end
    end

    describe '.alert_hooks' do
      it 'includes services where alert_events is true' do
        create(:service, active: true, alert_events: true)

        expect(described_class.alert_hooks.count).to eq 1
      end

      it 'excludes services where alert_events is false' do
        create(:service, active: true, alert_events: false)

        expect(described_class.alert_hooks.count).to eq 0
      end
    end
  end

  describe '#operating?' do
    it 'is false when the service is not active' do
      expect(build(:service).operating?).to eq(false)
    end

    it 'is false when the service is not persisted' do
      expect(build(:service, active: true).operating?).to eq(false)
    end

    it 'is true when the service is active and persisted' do
      expect(create(:service, active: true).operating?).to eq(true)
    end
  end

  describe "Test Button" do
    let(:service) { build(:service, project: project) }

    describe '#can_test?' do
      subject { service.can_test? }

      context 'when repository is not empty' do
        let(:project) { build(:project, :repository) }

        it { is_expected.to be true }
      end

      context 'when repository is empty' do
        let(:project) { build(:project) }

        it { is_expected.to be true }
      end

      context 'when instance-level service' do
        Service.available_services_types.each do |service_type|
          let(:service) do
            service_type.constantize.new(instance: true)
          end

          it { is_expected.to be_falsey }
        end
      end

      context 'when group-level service' do
        Service.available_services_types.each do |service_type|
          let(:service) do
            service_type.constantize.new(group_id: group.id)
          end

          it { is_expected.to be_falsey }
        end
      end
    end

    describe '#test' do
      let(:data) { 'test' }

      context 'when repository is not empty' do
        let(:project) { build(:project, :repository) }

        it 'test runs execute' do
          expect(service).to receive(:execute).with(data)

          service.test(data)
        end
      end

      context 'when repository is empty' do
        let(:project) { build(:project) }

        it 'test runs execute' do
          expect(service).to receive(:execute).with(data)

          service.test(data)
        end
      end
    end
  end

  describe '.find_or_initialize_integration' do
    let!(:service1) { create(:jira_service, project_id: nil, group_id: group.id) }
    let!(:service2) { create(:jira_service) }

    it 'returns the right service' do
      expect(Service.find_or_initialize_integration('jira', group_id: group)).to eq(service1)
    end

    it 'does not create a new service' do
      expect { Service.find_or_initialize_integration('redmine', group_id: group) }.not_to change { Service.count }
    end
  end

  describe '.find_or_initialize_all' do
    shared_examples 'service instances' do
      it 'returns the available service instances' do
        expect(Service.find_or_initialize_all(Service.for_instance).pluck(:type)).to match_array(Service.available_services_types)
      end

      it 'does not create service instances' do
        expect { Service.find_or_initialize_all(Service.for_instance) }.not_to change { Service.count }
      end
    end

    it_behaves_like 'service instances'

    context 'with all existing instances' do
      before do
        Service.insert_all(
          Service.available_services_types.map { |type| { instance: true, type: type } }
        )
      end

      it_behaves_like 'service instances'

      context 'with a previous existing service (MockCiService) and a new service (Asana)' do
        before do
          Service.insert(type: 'MockCiService', instance: true)
          Service.delete_by(type: 'AsanaService', instance: true)
        end

        it_behaves_like 'service instances'
      end
    end

    context 'with a few existing instances' do
      before do
        create(:jira_service, :instance)
      end

      it_behaves_like 'service instances'
    end
  end

  describe 'template' do
    shared_examples 'retrieves service templates' do
      it 'returns the available service templates' do
        expect(Service.find_or_create_templates.pluck(:type)).to match_array(Service.available_services_types)
      end
    end

    describe '.find_or_create_templates' do
      it 'creates service templates' do
        expect { Service.find_or_create_templates }.to change { Service.count }.from(0).to(Service.available_services_names.size)
      end

      it_behaves_like 'retrieves service templates'

      context 'with all existing templates' do
        before do
          Service.insert_all(
            Service.available_services_types.map { |type| { template: true, type: type } }
          )
        end

        it 'does not create service templates' do
          expect { Service.find_or_create_templates }.not_to change { Service.count }
        end

        it_behaves_like 'retrieves service templates'

        context 'with a previous existing service (Previous) and a new service (Asana)' do
          before do
            Service.insert(type: 'PreviousService', template: true)
            Service.delete_by(type: 'AsanaService', template: true)
          end

          it_behaves_like 'retrieves service templates'
        end
      end

      context 'with a few existing templates' do
        before do
          create(:jira_service, :template)
        end

        it 'creates the rest of the service templates' do
          expect { Service.find_or_create_templates }.to change { Service.count }.from(1).to(Service.available_services_names.size)
        end

        it_behaves_like 'retrieves service templates'
      end
    end

    describe '.build_from_integration' do
      context 'when integration is invalid' do
        let(:integration) do
          build(:prometheus_service, :template, active: true, properties: {})
            .tap { |integration| integration.save(validate: false) }
        end

        it 'sets service to inactive' do
          service = described_class.build_from_integration(project.id, integration)

          expect(service).to be_valid
          expect(service.active).to be false
        end
      end

      context 'when integration is an instance' do
        let(:integration) { create(:jira_service, :instance) }

        it 'sets inherit_from_id from integration' do
          service = described_class.build_from_integration(project.id, integration)

          expect(service.inherit_from_id).to eq(integration.id)
        end
      end

      describe 'build issue tracker from an integration' do
        let(:url) { 'http://jira.example.com' }
        let(:api_url) { 'http://api-jira.example.com' }
        let(:username) { 'jira-username' }
        let(:password) { 'jira-password' }
        let(:data_params) do
          {
            url: url, api_url: api_url,
            username: username, password: password
          }
        end

        shared_examples 'service creation from an integration' do
          it 'creates a correct service' do
            service = described_class.build_from_integration(project.id, integration)

            expect(service).to be_active
            expect(service.url).to eq(url)
            expect(service.api_url).to eq(api_url)
            expect(service.username).to eq(username)
            expect(service.password).to eq(password)
            expect(service.template).to eq(false)
            expect(service.instance).to eq(false)
          end
        end

        # this  will be removed as part of https://gitlab.com/gitlab-org/gitlab/issues/29404
        context 'when data are stored in properties' do
          let(:properties) { data_params }
          let!(:integration) do
            create(:jira_service, :without_properties_callback, template: true, properties: properties.merge(additional: 'something'))
          end

          it_behaves_like 'service creation from an integration'
        end

        context 'when data are stored in separated fields' do
          let(:integration) do
            create(:jira_service, :template, data_params.merge(properties: {}))
          end

          it_behaves_like 'service creation from an integration'
        end

        context 'when data are stored in both properties and separated fields' do
          let(:properties) { data_params }
          let(:integration) do
            create(:jira_service, :without_properties_callback, active: true, template: true, properties: properties).tap do |service|
              create(:jira_tracker_data, data_params.merge(service: service))
            end
          end

          it_behaves_like 'service creation from an integration'
        end
      end
    end

    describe "for pushover service" do
      let!(:service_template) do
        PushoverService.create(
          template: true,
          properties: {
            device: 'MyDevice',
            sound: 'mic',
            priority: 4,
            api_key: '123456789'
          })
      end

      describe 'is prefilled for projects pushover service' do
        it "has all fields prefilled" do
          service = project.find_or_initialize_service('pushover')

          expect(service.template).to eq(false)
          expect(service.device).to eq('MyDevice')
          expect(service.sound).to eq('mic')
          expect(service.priority).to eq(4)
          expect(service.api_key).to eq('123456789')
        end
      end
    end
  end

  describe '.default_integration' do
    context 'with an instance-level service' do
      let_it_be(:instance_service) { create(:jira_service, :instance) }

      it 'returns the instance service' do
        expect(described_class.default_integration('JiraService', project)).to eq(instance_service)
      end

      it 'returns nil for nonexistent service type' do
        expect(described_class.default_integration('HipchatService', project)).to eq(nil)
      end

      context 'with a group service' do
        let_it_be(:group_service) { create(:jira_service, group_id: group.id, project_id: nil) }

        it 'returns the group service for a project' do
          expect(described_class.default_integration('JiraService', project)).to eq(group_service)
        end

        it 'returns the instance service for a group' do
          expect(described_class.default_integration('JiraService', group)).to eq(instance_service)
        end

        context 'with a subgroup' do
          let_it_be(:subgroup) { create(:group, parent: group) }
          let!(:project) { create(:project, group: subgroup) }

          it 'returns the closest group service for a project' do
            expect(described_class.default_integration('JiraService', project)).to eq(group_service)
          end

          it 'returns the closest group service for a subgroup' do
            expect(described_class.default_integration('JiraService', subgroup)).to eq(group_service)
          end

          context 'having a service' do
            let!(:subgroup_service) { create(:jira_service, group_id: subgroup.id, project_id: nil) }

            it 'returns the closest group service for a project' do
              expect(described_class.default_integration('JiraService', project)).to eq(subgroup_service)
            end
          end
        end
      end
    end
  end

  describe "{property}_changed?" do
    let(:service) do
      BambooService.create(
        project: project,
        properties: {
          bamboo_url: 'http://gitlab.com',
          username: 'mic',
          password: "password"
        }
      )
    end

    it "returns false when the property has not been assigned a new value" do
      service.username = "key_changed"
      expect(service.bamboo_url_changed?).to be_falsy
    end

    it "returns true when the property has been assigned a different value" do
      service.bamboo_url = "http://example.com"
      expect(service.bamboo_url_changed?).to be_truthy
    end

    it "returns true when the property has been assigned a different value twice" do
      service.bamboo_url = "http://example.com"
      service.bamboo_url = "http://example.com"
      expect(service.bamboo_url_changed?).to be_truthy
    end

    it "returns false when the property has been re-assigned the same value" do
      service.bamboo_url = 'http://gitlab.com'
      expect(service.bamboo_url_changed?).to be_falsy
    end

    it "returns false when the property has been assigned a new value then saved" do
      service.bamboo_url = 'http://example.com'
      service.save
      expect(service.bamboo_url_changed?).to be_falsy
    end
  end

  describe "{property}_touched?" do
    let(:service) do
      BambooService.create(
        project: project,
        properties: {
          bamboo_url: 'http://gitlab.com',
          username: 'mic',
          password: "password"
        }
      )
    end

    it "returns false when the property has not been assigned a new value" do
      service.username = "key_changed"
      expect(service.bamboo_url_touched?).to be_falsy
    end

    it "returns true when the property has been assigned a different value" do
      service.bamboo_url = "http://example.com"
      expect(service.bamboo_url_touched?).to be_truthy
    end

    it "returns true when the property has been assigned a different value twice" do
      service.bamboo_url = "http://example.com"
      service.bamboo_url = "http://example.com"
      expect(service.bamboo_url_touched?).to be_truthy
    end

    it "returns true when the property has been re-assigned the same value" do
      service.bamboo_url = 'http://gitlab.com'
      expect(service.bamboo_url_touched?).to be_truthy
    end

    it "returns false when the property has been assigned a new value then saved" do
      service.bamboo_url = 'http://example.com'
      service.save
      expect(service.bamboo_url_changed?).to be_falsy
    end
  end

  describe "{property}_was" do
    let(:service) do
      BambooService.create(
        project: project,
        properties: {
          bamboo_url: 'http://gitlab.com',
          username: 'mic',
          password: "password"
        }
      )
    end

    it "returns nil when the property has not been assigned a new value" do
      service.username = "key_changed"
      expect(service.bamboo_url_was).to be_nil
    end

    it "returns the previous value when the property has been assigned a different value" do
      service.bamboo_url = "http://example.com"
      expect(service.bamboo_url_was).to eq('http://gitlab.com')
    end

    it "returns initial value when the property has been re-assigned the same value" do
      service.bamboo_url = 'http://gitlab.com'
      expect(service.bamboo_url_was).to eq('http://gitlab.com')
    end

    it "returns initial value when the property has been assigned multiple values" do
      service.bamboo_url = "http://example.com"
      service.bamboo_url = "http://example2.com"
      expect(service.bamboo_url_was).to eq('http://gitlab.com')
    end

    it "returns nil when the property has been assigned a new value then saved" do
      service.bamboo_url = 'http://example.com'
      service.save
      expect(service.bamboo_url_was).to be_nil
    end
  end

  describe 'initialize service with no properties' do
    let(:service) do
      BugzillaService.create(
        project: project,
        project_url: 'http://gitlab.example.com'
      )
    end

    it 'does not raise error' do
      expect { service }.not_to raise_error
    end

    it 'sets data correctly' do
      expect(service.data_fields.project_url).to eq('http://gitlab.example.com')
    end
  end

  describe "callbacks" do
    let!(:service) do
      RedmineService.new(
        project: project,
        active: true,
        properties: {
          project_url: 'http://redmine/projects/project_name_in_redmine',
          issues_url: "http://redmine/#{project.id}/project_name_in_redmine/:id",
          new_issue_url: 'http://redmine/projects/project_name_in_redmine/issues/new'
        }
      )
    end

    describe "on create" do
      it "updates the has_external_issue_tracker boolean" do
        expect do
          service.save!
        end.to change { service.project.has_external_issue_tracker }.from(false).to(true)
      end
    end

    describe "on update" do
      it "updates the has_external_issue_tracker boolean" do
        service.save!

        expect do
          service.update(active: false)
        end.to change { service.project.has_external_issue_tracker }.from(true).to(false)
      end
    end
  end

  describe '#api_field_names' do
    let(:fake_service) do
      Class.new(Service) do
        def fields
          [
            { name: 'token' },
            { name: 'api_token' },
            { name: 'key' },
            { name: 'api_key' },
            { name: 'password' },
            { name: 'password_field' },
            { name: 'safe_field' }
          ]
        end
      end
    end

    let(:service) do
      fake_service.new(properties: [
        { token: 'token-value' },
        { api_token: 'api_token-value' },
        { key: 'key-value' },
        { api_key: 'api_key-value' },
        { password: 'password-value' },
        { password_field: 'password_field-value' },
        { safe_field: 'safe_field-value' }
      ])
    end

    it 'filters out sensitive fields' do
      expect(service.api_field_names).to eq(['safe_field'])
    end
  end

  context 'logging' do
    let(:service) { build(:service, project: project) }
    let(:test_message) { "test message" }
    let(:arguments) do
      {
        service_class: service.class.name,
        project_path: project.full_path,
        project_id: project.id,
        message: test_message,
        additional_argument: 'some argument'
      }
    end

    it 'logs info messages using json logger' do
      expect(Gitlab::JsonLogger).to receive(:info).with(arguments)

      service.log_info(test_message, additional_argument: 'some argument')
    end

    it 'logs error messages using json logger' do
      expect(Gitlab::JsonLogger).to receive(:error).with(arguments)

      service.log_error(test_message, additional_argument: 'some argument')
    end
  end
end
