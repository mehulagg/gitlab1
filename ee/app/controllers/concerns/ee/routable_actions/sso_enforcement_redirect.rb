# frozen_string_literal: true

module EE
  module RoutableActions
    class SsoEnforcementRedirect
      include ::Gitlab::Routing
      include ::Gitlab::Utils::StrongMemoize

      attr_reader :routable

      def initialize(routable)
        @routable = routable
      end

      def should_redirect_to_group_saml_sso?(current_user, request)
        return false unless should_process?
        return false unless request.get?

        access_restricted_by_sso?(current_user)
      end

      def sso_redirect_url(current_user)
        sso_group_saml_providers_url(root_group, url_params(current_user))
      end

      module ControllerActions
        def self.on_routable_not_found
          lambda do |routable|
            redirector = SsoEnforcementRedirect.new(routable)

            if redirector.should_redirect_to_group_saml_sso?(current_user, request)
              redirect_to redirector.sso_redirect_url(current_user)
            end
          end
        end
      end

      private

      def access_restricted_by_sso?(current_user)
        Ability.policy_for(current_user, routable)&.needs_new_sso_session?
      end

      def should_process?
        group.present?
      end

      def group
        strong_memoize(:group) do
          case routable
          when ::Group
            routable
          when ::Project
            routable.group
          end
        end
      end

      def root_group
        @root_group ||= group.root_ancestor
      end

      def url_params(current_user)
        {
          token: root_group.saml_discovery_token,
          redirect: "/#{routable.full_path}",
          auto_redirect_to_provider: current_user.group_sso?(routable)
        }
      end
    end
  end
end
