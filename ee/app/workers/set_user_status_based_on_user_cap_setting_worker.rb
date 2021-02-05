# frozen_string_literal: true

class SetUserStatusBasedOnUserCapSettingWorker
  include ApplicationWorker
  include ::Gitlab::Utils::StrongMemoize

  feature_category :users

  idempotent!

  def perform(user_id)
    user = User.find_by_id(user_id)

    return unless user.blocked_pending_approval?
    return if user_cap_max.nil?
    return if user_cap_reached?

    if user.activate
      # Resends confirmation email if the user isn't confirmed yet.
      # Please see Devise's implementation of `resend_confirmation_instructions` for detail.
      user.resend_confirmation_instructions
      user.accept_pending_invitations! if user.active_for_authentication?
      DeviseMailer.user_admin_approval(user).deliver_later
    else
      logger.error(message: "Approval of user id=#{user_id} failed")
    end
  end

  private

  def user_cap_max
    strong_memoize(:user_cap_max) do
      ::Gitlab::CurrentSettings.new_user_signups_cap
    end
  end

  def current_billable_users_count
    strong_memoize(:user_cap_max) do
      User.billable.count
    end
  end

  def user_cap_reached?
    return false if current_billable_users_count < user_cap_max

    send_user_cap_reached_email if current_billable_users_count == user_cap_max

    true
  end

  def send_user_cap_reached_email
    User.admins.active.each do |user|
      ::Notify.user_cap_reached(user.id).deliver_later
    end
  end
end
