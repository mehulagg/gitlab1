require 'spec_helper'

describe OmniauthCallbacksController do
  include LoginHelpers

  let(:user) { create(:omniauth_user, extern_uid: 'my-uid', provider: provider) }
  let(:provider) { :github }

  before do
    mock_auth_hash(provider.to_s, 'my-uid', user.email)
    stub_omniauth_provider(provider, context: request)
  end

  it 'allows sign in' do
    post provider

    expect(request.env['warden']).to be_authenticated
  end

  shared_context 'sign_up' do
    let(:user) { double(email: 'new@example.com') }

    before do
      stub_omniauth_setting(block_auto_created_users: false)
    end
  end

  context 'sign up' do
    include_context 'sign_up'

    it 'is allowed' do
      post provider

      expect(request.env['warden']).to be_authenticated
    end
  end

  context 'when OAuth is disabled' do
    before do
      stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
      settings = Gitlab::CurrentSettings.current_application_settings
      settings.update(disabled_oauth_sign_in_sources: [provider.to_s])
    end

    it 'prevents login via POST' do
      post provider

      expect(request.env['warden']).not_to be_authenticated
    end

    it 'shows warning when attempting login' do
      post provider

      expect(response).to redirect_to new_user_session_path
      expect(flash[:alert]).to eq('Signing in using GitHub has been disabled')
    end

    it 'allows linking the disabled provider' do
      user.identities.destroy_all
      sign_in(user)

      expect { post provider }.to change { user.reload.identities.count }.by(1)
    end

    context 'sign up' do
      include_context 'sign_up'

      it 'is prevented' do
        post provider

        expect(request.env['warden']).not_to be_authenticated
      end
    end
  end
end
