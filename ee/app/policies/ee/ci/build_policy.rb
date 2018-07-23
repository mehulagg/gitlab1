module EE
  module Ci
    module BuildPolicy
      extend ActiveSupport::Concern

      prepended do
        with_scope :subject

        condition(:has_environment) { @subject.has_environment? }

        condition(:protected_environment_user_allowed) do
          environment_is_protected?(@subject.expanded_environment_name, @user)
        end

        rule { has_environment & ~protected_environment_user_allowed }.policy do
          prevent :update_build
        end

        private

        def environment_is_protected?(environment_name, user)
          @subject.project.protected_environment_accessible_to?(environment_name, user)
        end
      end
    end
  end
end
