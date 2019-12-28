# frozen_string_literal: true

require 'spec_helper'

describe Admin::SessionsController, :do_not_mock_admin_mode do
  include_context 'custom session'

  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  describe '#new' do
    context 'for regular users' do
      it 'shows error page' do
        get :new

        expect(response).to have_gitlab_http_status(:not_found)
        expect(controller.current_user_mode.admin_mode?).to be(false)
      end
    end

    context 'for admin users' do
      let(:user) { create(:admin) }

      it 'renders a password form' do
        get :new

        expect(response).to render_template :new
        expect(controller.current_user_mode.admin_mode?).to be(false)
      end

      context 'already in admin mode' do
        before do
          controller.current_user_mode.request_admin_mode!
          controller.current_user_mode.enable_admin_mode!(password: user.password)
        end

        it 'redirects to original location' do
          get :new

          expect(response).to redirect_to(admin_root_path)
          expect(controller.current_user_mode.admin_mode?).to be(true)
        end
      end
    end
  end

  describe '#create' do
    context 'for regular users' do
      it 'shows error page' do
        post :create

        expect(response).to have_gitlab_http_status(:not_found)
        expect(controller.current_user_mode.admin_mode?).to be(false)
      end
    end

    context 'for admin users' do
      let(:user) { create(:admin) }

      it 'sets admin mode with a valid password' do
        expect(controller.current_user_mode.admin_mode?).to be(false)

        controller.store_location_for(:redirect, admin_root_path)

        # triggering the auth form will request admin mode
        get :new

        post :create, params: { password: user.password }

        expect(response).to redirect_to admin_root_path
        expect(controller.current_user_mode.admin_mode?).to be(true)
      end

      it 'fails with an invalid password' do
        expect(controller.current_user_mode.admin_mode?).to be(false)

        controller.store_location_for(:redirect, admin_root_path)

        # triggering the auth form will request admin mode
        get :new

        post :create, params: { password: '' }

        expect(response).to render_template :new
        expect(controller.current_user_mode.admin_mode?).to be(false)
      end

      it 'fails if not requested first' do
        expect(controller.current_user_mode.admin_mode?).to be(false)

        controller.store_location_for(:redirect, admin_root_path)

        # do not trigger the auth form

        post :create, params: { password: user.password }

        expect(response).to redirect_to(new_admin_session_path)
        expect(controller.current_user_mode.admin_mode?).to be(false)
      end

      it 'fails if request period expired' do
        expect(controller.current_user_mode.admin_mode?).to be(false)

        controller.store_location_for(:redirect, admin_root_path)

        # triggering the auth form will request admin mode
        get :new

        Timecop.freeze(Gitlab::Auth::CurrentUserMode::ADMIN_MODE_REQUESTED_GRACE_PERIOD.from_now) do
          post :create, params: { password: user.password }

          expect(response).to redirect_to(new_admin_session_path)
          expect(controller.current_user_mode.admin_mode?).to be(false)
        end
      end

      context 'when using two-factor authentication via OTP' do
        let(:user) { create(:admin, :two_factor) }

        def authenticate_2fa(params)
          post(:create, params: params, session: { otp_user_id: user.id })
        end

        it 'requests two factor after a valid password is provided' do
          expect(controller.current_user_mode.admin_mode?).to be(false)

          # triggering the auth form will request admin mode
          get :new
          post :create, params: { password: user.password }

          expect(response).to render_template('admin/sessions/two_factor')
          expect(controller.current_user_mode.admin_mode?).to be(false)
        end

        it 'can login with valid otp' do
          expect(controller.current_user_mode.admin_mode?).to be(false)

          controller.store_location_for(:redirect, admin_root_path)
          controller.current_user_mode.request_admin_mode!

          authenticate_2fa(otp_attempt: user.current_otp)

          expect(response).to redirect_to admin_root_path
          expect(controller.current_user_mode.admin_mode?).to be(true)
        end

        it 'cannot login with invalid otp' do
          expect(controller.current_user_mode.admin_mode?).to be(false)

          controller.current_user_mode.request_admin_mode!
          authenticate_2fa(otp_attempt: 'invalid')

          expect(response).to render_template('admin/sessions/two_factor')
          expect(controller.current_user_mode.admin_mode?).to be(false)
        end
      end

      context 'when using two-factor authentication via U2F' do
        let(:user) { create(:admin, :two_factor_via_u2f) }

        def authenticate_2fa_u2f(params)
          post(:create, params: params, session: { otp_user_id: user.id })
        end

        it 'requests two factor after a valid password is provided' do
          expect(controller.current_user_mode.admin_mode?).to be(false)

          # triggering the auth form will request admin mode
          get :new
          post :create, params: { password: user.password }

          expect(response).to render_template('admin/sessions/two_factor')
          expect(controller.current_user_mode.admin_mode?).to be(false)
        end

        it 'can login with valid auth' do
          allow(U2fRegistration).to receive(:authenticate).and_return(true)

          expect(controller.current_user_mode.admin_mode?).to be(false)

          controller.store_location_for(:redirect, admin_root_path)
          controller.current_user_mode.request_admin_mode!

          authenticate_2fa_u2f(login: user.username, device_response: '{}')

          expect(response).to redirect_to admin_root_path
          expect(controller.current_user_mode.admin_mode?).to be(true)
        end

        it 'cannot login with invalid auth' do
          allow(U2fRegistration).to receive(:authenticate).and_return(false)

          expect(controller.current_user_mode.admin_mode?).to be(false)

          controller.current_user_mode.request_admin_mode!
          authenticate_2fa_u2f(login: user.username, device_response: '{}')

          expect(response).to render_template('admin/sessions/two_factor')
          expect(controller.current_user_mode.admin_mode?).to be(false)
        end
      end
    end
  end

  describe '#destroy' do
    context 'for regular users' do
      it 'shows error page' do
        post :destroy

        expect(response).to have_gitlab_http_status(:not_found)
        expect(controller.current_user_mode.admin_mode?).to be(false)
      end
    end

    context 'for admin users' do
      let(:user) { create(:admin) }

      it 'disables admin mode and redirects to main page' do
        expect(controller.current_user_mode.admin_mode?).to be(false)

        get :new
        post :create, params: { password: user.password }
        expect(controller.current_user_mode.admin_mode?).to be(true)

        post :destroy

        expect(response).to have_gitlab_http_status(:found)
        expect(response).to redirect_to(root_path)
        expect(controller.current_user_mode.admin_mode?).to be(false)
      end
    end
  end
end
