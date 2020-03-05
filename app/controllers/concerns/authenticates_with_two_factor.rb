# frozen_string_literal: true
require 'webauthn/u2f_migrator'

# == AuthenticatesWithTwoFactor
#
# Controller concern to handle two-factor authentication
module AuthenticatesWithTwoFactor
  extend ActiveSupport::Concern

  # Store the user's ID in the session for later retrieval and render the
  # two factor code prompt
  #
  # The user must have been authenticated with a valid login and password
  # before calling this method!
  #
  # user - User record
  #
  # Returns nil
  def prompt_for_two_factor(user)
    # Set @user for Devise views
    @user = user # rubocop:disable Gitlab/ModuleWithInstanceVariables

    return handle_locked_user(user) unless user.can?(:log_in)

    session[:otp_user_id] = user.id
    push_frontend_feature_flag(:webauthn, user)

    if Feature.enabled?(:webauthn, user)
      setup_webauthn_authentication(user)
    else
      setup_u2f_authentication(user)
    end
    render 'devise/sessions/two_factor'
  end

  def handle_locked_user(user)
    clear_two_factor_attempt!

    locked_user_redirect(user)
  end

  def locked_user_redirect(user)
    flash.now[:alert] = locked_user_redirect_alert(user)

    render 'devise/sessions/new'
  end

  def authenticate_with_two_factor
    user = self.resource = find_user
    return handle_locked_user(user) unless user.can?(:log_in)

    if user_params[:otp_attempt].present? && session[:otp_user_id]
      authenticate_with_two_factor_via_otp(user)
    elsif user_params[:device_response].present? && session[:otp_user_id]
      if Feature.enabled?(:webauthn, user)
        authenticate_with_two_factor_via_webauthn(user)
      else
        authenticate_with_two_factor_via_u2f(user)
      end
    elsif user && user.valid_password?(user_params[:password])
      prompt_for_two_factor(user)
    end
  end

  private

  def locked_user_redirect_alert(user)
    user.access_locked? ? _('Your account is locked.') : _('Invalid Login or password')
  end

  def clear_two_factor_attempt!
    session.delete(:otp_user_id)
  end

  def authenticate_with_two_factor_via_otp(user)
    if valid_otp_attempt?(user)
      # Remove any lingering user data from login
      session.delete(:otp_user_id)

      remember_me(user) if user_params[:remember_me] == '1'
      user.save!
      sign_in(user, message: :two_factor_authenticated, event: :authentication)
    else
      user.increment_failed_attempts!
      Gitlab::AppLogger.info("Failed Login: user=#{user.username} ip=#{request.remote_ip} method=OTP")
      flash.now[:alert] = _('Invalid two-factor code.')
      prompt_for_two_factor(user)
    end
  end

  # Authenticate using the response from a U2F (universal 2nd factor) device
  def authenticate_with_two_factor_via_u2f(user)
    if U2fRegistration.authenticate(user, u2f_app_id, user_params[:device_response], session[:challenge])
      handle_two_factor_success(user)
    else
      user.increment_failed_attempts!
      Gitlab::AppLogger.info("Failed Login: user=#{user.username} ip=#{request.remote_ip} method=U2F")
      flash.now[:alert] = _('Authentication via U2F device failed.')
      prompt_for_two_factor(user)
    end
  end

  def authenticate_with_two_factor_via_webauthn(user)
    if Webauthn::AuthenticateService.new(user, user_params[:device_response], session[:challenge], u2f_app_id).execute
      handle_two_factor_success(user)
    else
      user.increment_failed_attempts!
      Gitlab::AppLogger.info("Failed Login: user=#{user.username} ip=#{request.remote_ip} method=WebAuthn")
      flash.now[:alert] = _('Authentication via WebAuthn device failed.')
      prompt_for_two_factor(user)
    end
  end

  # Setup in preparation of communication with a U2F (universal 2nd factor) device
  # Actual communication is performed using a Javascript API
  # rubocop: disable CodeReuse/ActiveRecord
  def setup_u2f_authentication(user)
    key_handles = user.u2f_registrations.pluck(:key_handle)
    u2f = U2F::U2F.new(u2f_app_id)

    if key_handles.present?
      sign_requests = u2f.authentication_requests(key_handles)
      session[:challenge] ||= u2f.challenge
      gon.push(u2f: { challenge: session[:challenge], app_id: u2f_app_id,
                      sign_requests: sign_requests })
    end
  end

  def setup_webauthn_authentication(user)
    if user.u2f_registrations.present? || user.webauthn_registrations.present?

      all_webauthn_registration_ids = user.webauthn_registrations.pluck(:external_id) +
          user.converted_webauthn_registrations.pluck(:external_id)

      get_options = WebAuthn::Credential.options_for_get(allow: all_webauthn_registration_ids,
                                                         user_verification: 'discouraged',
                                                         extensions: { appid: u2f_app_id })

      session[:credentialRequestOptions] = get_options
      session[:challenge] = get_options.challenge
      gon.push(webauthn: { options: get_options.to_json })
    end
  end

  # rubocop: enable CodeReuse/ActiveRecord

  private

  def handle_two_factor_success(user)
    # Remove any lingering user data from login
    session.delete(:otp_user_id)
    session.delete(:challenge)

    remember_me(user) if user_params[:remember_me] == '1'
    sign_in(user, message: :two_factor_authenticated, event: :authentication)
  end
end
