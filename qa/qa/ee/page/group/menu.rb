# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        class Menu < ::QA::Page::Base
          view 'ee/app/views/groups/ee/_settings_nav.html.haml' do
            element :group_saml_sso_link
            element :ldap_synchronization_link
          end

          view 'app/views/layouts/nav/sidebar/_group.html.haml' do
            element :group_sidebar
            element :group_sidebar_submenu
            element :group_settings_item
            element :group_members_item
            element :general_settings_link
          end

          view 'ee/app/views/layouts/nav/ee/_epic_link.html.haml' do
            element :group_epics_link
          end

          view 'ee/app/views/layouts/nav/ee/_security_link.html.haml' do
            element :security_dashboard_link
          end

          view 'ee/app/views/layouts/nav/_group_insights_link.html.haml' do
            element :group_insights_link
          end

          view 'app/views/layouts/nav/sidebar/_group.html.haml' do
            element :group_issue_boards_link
            element :group_issues_item
          end

          def go_to_issue_boards
            hover_element(:group_issues_item) do
              within_submenu(:group_issues_sidebar_submenu) do
                click_element(:group_issue_boards_link)
              end
            end
          end

          def go_to_saml_sso_group_settings
            hover_element(:group_settings_item) do
              within_submenu(:group_sidebar_submenu) do
                click_element(:group_saml_sso_link)
              end
            end
          end

          def go_to_ldap_sync_settings
            hover_element(:group_settings_item) do
              within_submenu(:group_sidebar_submenu) do
                click_element(:ldap_synchronization_link)
              end
            end
          end

          def click_group_insights_link
            within_sidebar do
              click_element(:group_insights_link)
            end
          end

          def click_group_members_item
            within_sidebar do
              click_element(:group_members_item)
            end
          end

          def click_group_general_settings_item
            hover_element(:group_settings_item) do
              within_submenu(:group_sidebar_submenu) do
                click_element(:general_settings_link)
              end
            end
          end

          def click_group_epics_link
            within_sidebar do
              click_element(:group_epics_link)
            end
          end

          def click_group_security_link
            within_sidebar do
              click_element(:security_dashboard_link)
            end
          end

          private

          def hover_element(element)
            within_sidebar do
              find_element(element).hover
              yield
            end
          end

          def within_sidebar
            within_element(:group_sidebar) do
              yield
            end
          end

          def within_submenu(element)
            within_element(element) do
              yield
            end
          end
        end
      end
    end
  end
end
