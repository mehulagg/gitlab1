# frozen_string_literal: true

module EE
  # PersonalAccessToken EE mixin
  #
  # This module is intended to encapsulate EE-specific model logic
  # and be prepended in the `PersonalAccessToken` model
  module PersonalAccessToken
    extend ActiveSupport::Concern

    prepended do
      include ::Gitlab::Utils::StrongMemoize
      include FromUnion

      scope :with_no_expires_at, -> { where(revoked: false, expires_at: nil) }
      scope :with_expires_at_after, ->(max_lifetime) { where(revoked: false).where('expires_at > ?', max_lifetime) }

      with_options if: :personal_access_token_expiration_policy_enabled? do
        validates :expires_at, presence: true
        validate :expires_at_before_personal_access_token_max_expiry_date
      end
    end

    class_methods do
      def pluck_names
        pluck(:name)
      end

      def with_invalid_expires_at(max_lifetime, limit = 1_000)
        from_union(
          [
            with_no_expires_at.limit(limit),
            with_expires_at_after(max_lifetime).limit(limit)
          ]
        )
      end
    end

    private

    def personal_access_token_expiration_policy_enabled?
      return group_level_personal_access_token_expiration_policy_enabled? if user.group_managed_account?

      instance_level_personal_access_token_expiration_policy_enabled?
    end

    def instance_level_personal_access_token_expiration_policy_enabled?
      instance_level_personal_access_token_max_expiry_date && personal_access_token_expiration_policy_licensed?
    end

    def personal_access_token_max_expiry_date
      return group_level_personal_access_token_max_expiry_date if user.group_managed_account?

      instance_level_personal_access_token_max_expiry_date
    end

    def instance_level_personal_access_token_max_expiry_date
      strong_memoize(:instance_level_personal_access_token_max_expiry_date) do
        ::Gitlab::CurrentSettings.max_personal_access_token_lifetime_from_now
      end
    end

    def expires_at_before_personal_access_token_max_expiry_date
      return if expires_at.blank?

      errors.add(:expires_at, :invalid) if expires_at > personal_access_token_max_expiry_date
    end

    def personal_access_token_expiration_policy_licensed?
      License.feature_available?(:personal_access_token_expiration_policy)
    end

    def group_level_personal_access_token_expiration_policy_enabled?
      group_level_personal_access_token_max_expiry_date && personal_access_token_expiration_policy_licensed?
    end

    def group_level_personal_access_token_max_expiry_date
      strong_memoize(:group_level_personal_access_token_max_expiry_date) do
        user.managing_group.max_personal_access_token_lifetime_from_now
      end
    end
  end
end
