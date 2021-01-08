# frozen_string_literal: true

class Oauth::AuthorizationsController < Doorkeeper::AuthorizationsController
  include Gitlab::Experimentation::ControllerConcern
  include InitializesCurrentUserMode

  before_action :verify_confirmed_email!

  layout 'profile'

  # Overridden from Doorkeeper::AuthorizationsController to
  # include the call to session.delete
  def new
    if pre_auth.authorizable?
      if skip_authorization? || matching_token?
        auth = authorization.authorize
        session.delete(:user_return_to)
        redirect_to auth.redirect_uri
      else
        render "doorkeeper/authorizations/new"
      end
    else
      render "doorkeeper/authorizations/error"
    end
  end

  def create
    # Confidential apps require the client_secret to be sent with the request.
    # Doorkeeper allows implicit grant flow requests (response_type=token) to
    # work without client_secret regardless of the confidential setting.
    if pre_auth.authorizable? && pre_auth.response_type == 'token' && pre_auth.client.application.confidential
      render "doorkeeper/authorizations/error"
    else
      super
    end
  end

  private

  def verify_confirmed_email!
    return if current_user&.confirmed?

    pre_auth.error = :unconfirmed_email
    render "doorkeeper/authorizations/error"
  end
end
