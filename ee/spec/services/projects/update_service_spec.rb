require 'spec_helper'

describe Projects::UpdateService, '#execute' do
  include EE::GeoHelpers

  let(:user) { create(:user) }
  let(:project) { create(:project, :repository, creator: user, namespace: user.namespace) }

  context 'repository mirror' do
    let!(:opts) do
      {
      }
    end

    before do
      stub_licensed_features(repository_mirrors: true)
    end

    it 'forces an import job' do
      opts = {
        import_url: 'http://foo.com',
        mirror: true,
        mirror_user_id: user.id,
        mirror_trigger_builds: true
      }

      expect_any_instance_of(EE::ProjectImportState).to receive(:force_import_job!).once

      update_project(project, user, opts)
    end
  end

  context 'audit events' do
    let(:audit_event_params) do
      {
        author_id: user.id,
        entity_id: project.id,
        entity_type: 'Project',
        details: {
          author_name: user.name,
          target_id: project.id,
          target_type: 'Project',
          target_details: project.full_path
        }
      }
    end

    context '#name' do
      include_examples 'audit event logging' do
        let!(:old_name) { project.full_name }
        let(:operation) { update_project(project, user, name: 'foobar') }
        let(:fail_condition!) do
          allow_any_instance_of(Project).to receive(:update).and_return(false)
        end

        let(:attributes) do
          audit_event_params.tap do |param|
            param[:details].merge!(
              change: 'name',
              from: old_name,
              to: project.full_name
            )
          end
        end
      end
    end

    context '#path' do
      include_examples 'audit event logging' do
        let(:operation) { update_project(project, user, path: 'foobar1') }
        let(:fail_condition!) do
          allow_any_instance_of(Project).to receive(:update).and_return(false)
        end

        let(:attributes) do
          audit_event_params.tap do |param|
            param[:details].merge!(
              change: 'path',
              from: project.old_path_with_namespace,
              to: project.full_path
            )
          end
        end
      end
    end

    context '#visibility' do
      include_examples 'audit event logging' do
        let(:operation) do
          update_project(project, user, visibility_level: Gitlab::VisibilityLevel::INTERNAL)
        end
        let(:fail_condition!) do
          allow_any_instance_of(Project).to receive(:update).and_return(false)
        end

        let(:attributes) do
          audit_event_params.tap do |param|
            param[:details].merge!(
              change: 'visibility',
              from: 'Private',
              to: 'Internal'
            )
          end
        end
      end
    end
  end

  context 'triggering wiki Geo syncs', :geo do
    context 'on a Geo primary' do
      set(:primary)   { create(:geo_node, :primary) }
      set(:secondary) { create(:geo_node) }

      before do
        stub_current_geo_node(primary)
      end

      context 'when enabling a wiki' do
        it 'creates a RepositoryUpdatedEvent' do
          project.project_feature.update(wiki_access_level: ProjectFeature::DISABLED)
          project.reload

          expect do
            result = update_project(project, user, project_feature_attributes: { wiki_access_level: ProjectFeature::ENABLED })
            expect(result).to eq({ status: :success })
          end.to change { Geo::RepositoryUpdatedEvent.count }.by(1)

          expect(project.wiki_enabled?).to be true
        end
      end

      context 'when we update project but not enabling a wiki' do
        context 'when the wiki is disabled' do
          it 'does not create a RepositoryUpdatedEvent' do
            project.project_feature.update(wiki_access_level: ProjectFeature::DISABLED)

            expect do
              result = update_project(project, user, { name: 'test1' })
              expect(result).to eq({ status: :success })
            end.not_to change { Geo::RepositoryUpdatedEvent.count }

            expect(project.wiki_enabled?).to be false
          end
        end

        context 'when the wiki was already enabled' do
          it 'does not create a RepositoryUpdatedEvent' do
            project.project_feature.update(wiki_access_level: ProjectFeature::ENABLED)

            expect do
              result = update_project(project, user, { name: 'test1' })
              expect(result).to eq({ status: :success })
            end.not_to change { Geo::RepositoryUpdatedEvent.count }

            expect(project.wiki_enabled?).to be true
          end
        end
      end
    end

    context 'not on a Geo node' do
      before do
        allow(::Gitlab::Geo).to receive(:current_node).and_return(nil)
      end

      it 'does not create a RepositoryUpdatedEvent when enabling a wiki' do
        project.project_feature.update(wiki_access_level: ProjectFeature::DISABLED)
        project.reload

        expect do
          result = update_project(project, user, project_feature_attributes: { wiki_access_level: ProjectFeature::ENABLED })
          expect(result).to eq({ status: :success })
        end.not_to change { Geo::RepositoryUpdatedEvent.count }

        expect(project.wiki_enabled?).to be true
      end
    end
  end

  context 'with approval_rules' do
    context 'when approval_rules is disabled' do
      it "updates approval_rules' approvals_required" do
        stub_feature_flags(approval_rules: false)

        rule = create(:approval_project_rule, project: project)

        update_project(project, user, approvals_before_merge: 42)

        expect(rule.reload.approvals_required).to eq(42)
      end
    end

    context 'when approval_rules is enabled' do
      it 'does not update' do
        rule = create(:approval_project_rule, project: project)

        update_project(project, user, approvals_before_merge: 42)

        expect(rule.reload.approvals_required).to eq(0)
      end
    end

    context 'when approval_rule feature is enabled' do
      it "does not update approval_rules' approvals_required" do
        rule = create(:approval_project_rule, project: project)

        expect do
          update_project(project, user, approvals_before_merge: 42)
        end.not_to change { rule.reload.approvals_required }
      end
    end
  end

  describe 'repository_storage' do
    let(:admin_user) { create(:user, admin: true) }
    let(:user) { create(:user) }
    let(:project) { create(:project, :repository) }
    let(:opts) { { repository_storage: 'b' } }

    before do
      FileUtils.mkdir('tmp/tests/storage_b')

      storages = {
          'default' => Gitlab.config.repositories.storages.default,
          'b' => { 'path' => 'tmp/tests/storage_b' }
      }
      stub_storage_settings(storages)
    end

    after do
      FileUtils.rm_rf('tmp/tests/storage_b')
    end

    it 'calls the change repository storage method if the storage changed' do
      expect(project).to receive(:change_repository_storage).with('b')

      update_project(project, admin_user, opts).inspect
    end

    it "doesn't call the change repository storage for non-admin users" do
      expect(project).not_to receive(:change_repository_storage)

      update_project(project, user, opts).inspect
    end
  end

  context 'repository_size_limit assignment as Bytes' do
    let(:admin_user) { create(:user, admin: true) }
    let(:project) { create(:project, repository_size_limit: 0) }

    context 'when param present' do
      let(:opts) { { repository_size_limit: '100' } }

      it 'converts from MB to Bytes' do
        update_project(project, admin_user, opts)

        expect(project.reload.repository_size_limit).to eql(100 * 1024 * 1024)
      end
    end

    context 'when param not present' do
      let(:opts) { { repository_size_limit: '' } }

      it 'assign nil value' do
        update_project(project, admin_user, opts)

        expect(project.reload.repository_size_limit).to be_nil
      end
    end
  end

  it 'returns an error result when record cannot be updated' do
    admin = create(:admin)

    result = update_project(project, admin, { name: 'foo&bar' })

    expect(result).to eq({ status: :error, message: "Name can contain only letters, digits, emojis, '_', '.', dash, space. It must start with letter, digit, emoji or '_'." })
  end

  def update_project(project, user, opts)
    Projects::UpdateService.new(project, user, opts).execute
  end
end
