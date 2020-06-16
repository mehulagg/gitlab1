# frozen_string_literal: true

# Include this module to have an object respond to user messages without being
# a user.
#
# Use Case 1:
# Pass something else than the user to check policies. This defines several
# methods which the policy checker would call and check.
#
# Use Case 2:
# Access the API with non-user object such as deploy tokens. This defines
# several methods which the API auth flow would call.
module PolicyActor
  extend ActiveSupport::Concern

  def blocked?
    false
  end

  def admin?
    false
  end

  def external?
    false
  end

  def internal?
    false
  end

  def access_locked?
    false
  end

  def required_terms_not_accepted?
    false
  end

  def can_create_group
    false
  end

  def alert_bot?
    false
  end

  def deactivated?
    false
  end

  def confirmation_required_on_sign_in?
    false
  end

  def can?(action, subject = :global)
    Ability.allowed?(self, action, subject)
  end

  def preferred_language
    nil
  end

  def requires_ldap_check?
    false
  end

  def try_obtain_ldap_lease
    nil
  end
end

PolicyActor.prepend_if_ee('EE::PolicyActor')
