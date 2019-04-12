require 'spec_helper'

describe GroupsController do
  include ExternalAuthorizationServiceHelpers

  let(:user) { create(:user) }
  let(:group) { create(:group) }

  before do
    sign_in(user)
  end

  describe 'external authorization' do
    before do
      group.add_owner(user)
      sign_in(user)
    end

    context 'with external authorization service enabled' do
      before do
        enable_external_authorization_service_check
      end

      describe 'PUT #update' do
        context 'no license' do
          it 'does not update the file_template_project_id successfully' do
            project = create(:project, group: group)

            stub_licensed_features(custom_file_templates_for_namespace: false)

            expect do
              post :update, params: { id: group.to_param, group: { file_template_project_id: project.id } }
            end.not_to change { group.reload.file_template_project_id }
          end
        end

        context 'with license' do
          it 'updates the file_template_project_id successfully' do
            project = create(:project, group: group)

            stub_licensed_features(custom_file_templates_for_namespace: true)

            expect do
              post :update, params: { id: group.to_param, group: { file_template_project_id: project.id } }
            end.to change { group.reload.file_template_project_id }.to(project.id)
          end

          it 'updates insight project_id successfully' do
            project = create(:project, group: group)

            stub_licensed_features(insights: true)

            post :update, params: { id: group.to_param, group: { insight_attributes: { project_id: project.id } } }

            expect(group.reload.insight.project).to eq(project)
          end
        end
      end
    end
  end

  describe '"group overview content" preference behaviour' do
    describe 'GET #show' do
      subject { get :show, params: { id: group.to_param }, format: format }

      let(:format) { :html }

      context 'with user having proper permissions and feature enabled' do
        before do
          stub_licensed_features(security_dashboard: true)
          group.add_developer(user)
        end

        context 'with group view set as default' do
          it 'renders the expected template' do
            expect(subject).to render_template('groups/show')
          end
        end

        context 'with group view set to security dashboard' do
          let(:user) { create(:user, group_view: :security_dashboard) }

          context 'in HTML format' do
            it 'redirects to the security dashboard' do
              expect(subject).to redirect_to(group_security_dashboard_url(group))
            end
          end

          context 'in Atom format' do
            let(:format) { :atom }

            it 'does not redirect to the security dashboard' do
              expect(subject).to render_template('groups/show')
            end
          end

          context 'and the feature flag is disabled' do
            before do
              stub_feature_flags(group_overview_security_dashboard: false)
            end

            it 'renders the expected template' do
              expect(subject).to render_template('groups/show')
            end
          end
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(group_overview_security_dashboard: false)
        end

        let(:user) { create(:user, group_view: :security_dashboard) } # not a member of a group

        context 'when security dashboard feature is enabled' do
          before do
            stub_licensed_features(security_dashboard: true)
          end

          context 'when user is not allowed to access group security dashboard' do
            it 'works because security dashboard is not rendered' do
              expect(subject).to have_gitlab_http_status(200)
            end
          end
        end

        context 'when security dashboard feature is disabled' do
          it 'works because security dashboard is not rendered' do
            expect(subject).to have_gitlab_http_status(200)
          end
        end
      end
    end

    describe 'GET #details' do
      subject { get :details, params: { id: group.to_param } }

      context 'with user having proper permissions and feature enabled' do
        before do
          stub_licensed_features(security_dashboard: true)
          group.add_developer(user)
        end

        context 'with group view set to security dashboard' do
          let(:user) { create(:user, group_view: :security_dashboard) }

          it 'does not redirect to the security dashboard' do
            expect(subject).not_to redirect_to(group_security_dashboard_url(group))
          end

          context 'and the feature flag is disabled' do
            before do
              stub_feature_flags(group_overview_security_dashboard: false)
            end

            it 'renders the expected template' do
              expect(subject).to render_template('groups/show')
            end
          end
        end
      end
    end
  end
end
