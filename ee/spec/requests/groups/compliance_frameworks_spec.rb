# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'group compliance frameworks' do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  before do
    login_as(user)
  end

  context 'when compliance frameworks feature is disabled' do
    before do
      stub_feature_flags(ff_custom_compliance_frameworks: false)
      stub_licensed_features(custom_compliance_frameworks: false)
    end

    describe 'GET /groups/:group/-/compliance_frameworks/new' do
      it 'returns 404 not found' do
        get new_group_compliance_framework_path(group)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  context 'when compliance frameworks feature is enabled' do
    before do
      stub_feature_flags(ff_custom_compliance_frameworks: true)
      stub_licensed_features(custom_compliance_frameworks: true)
    end

    describe 'GET /groups/:group/-/compliance_frameworks/new' do
      it 'renders template' do
        group.add_owner(user)
        get new_group_compliance_framework_path(group)

        expect(response).to render_template 'groups/compliance_frameworks/new'
      end

      context 'with unauthorized user' do
        it 'returns 404 not found' do
          get new_group_compliance_framework_path(group)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
