# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group navbar' do
  include NavbarStructureHelper
  include WaitForRequests

  include_context 'group navbar structure'

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  before do
    group.add_maintainer(user)
    stub_feature_flags(group_push_rules: false)
    stub_feature_flags(group_iterations: false)
    sign_in(user)
  end

  context 'when productivity analytics is available' do
    before do
      stub_licensed_features(productivity_analytics: true)

      insert_after_sub_nav_item(
        _('Contribution'),
        within: _('Analytics'),
        new_sub_nav_item_name: _('Productivity')
      )

      visit group_path(group)
    end

    it_behaves_like 'verified navigation bar'
  end

  context 'when value stream analytics is available' do
    before do
      stub_licensed_features(cycle_analytics_for_groups: true)

      insert_after_sub_nav_item(
        _('Contribution'),
        within: _('Analytics'),
        new_sub_nav_item_name: _('Value Stream')
      )

      visit group_path(group)
    end

    it_behaves_like 'verified navigation bar'

    it 'redirects to value stream when Analytics item is clicked' do
      page.within('.sidebar-top-level-items') do
        find('[data-qa-selector=analytics_anchor]').click
      end

      wait_for_requests

      expect(page).to have_current_path(group_analytics_cycle_analytics_path(group))
    end
  end

  context 'when epics are available' do
    before do
      stub_licensed_features(epics: true)

      insert_after_nav_item(
        _('Group overview'),
        new_nav_item: {
          nav_item: _('Epics'),
          nav_sub_items: [
            _('List'),
            _('Roadmap')
          ]
        }
      )

      visit group_path(group)
    end

    it_behaves_like 'verified navigation bar'
  end

  context 'when the logged in user is the owner' do
    before do
      group.add_owner(user)

      insert_after_nav_item(_('Members'), new_nav_item: settings_nav_item)
      insert_after_nav_item(_('Settings'), new_nav_item: administration_nav_item)

      visit group_path(group)
    end

    it_behaves_like 'verified navigation bar'
  end

  context 'when SAML SSO is available' do
    before do
      stub_licensed_features(group_saml: true)

      group.add_owner(user)

      insert_after_nav_item(_('Members'), new_nav_item: settings_nav_item)
      insert_after_nav_item(
        _('Settings'),
        new_nav_item: {
          nav_item: _('Administration'),
          nav_sub_items: [
            _('SAML SSO'),
            s_('UsageQuota|Usage Quotas')
          ]
        }
      )

      visit group_path(group)
    end

    it_behaves_like 'verified navigation bar'
  end

  context 'when security dashboard is available' do
    before do
      group.add_owner(user)

      stub_licensed_features(security_dashboard: true, group_level_compliance_dashboard: true)

      insert_after_nav_item(
        _('Merge Requests'),
        new_nav_item: {
          nav_item: _('Security & Compliance'),
          nav_sub_items: [
            _('Security'),
            _('Compliance')
          ]
        }
      )

      insert_after_nav_item(_('Members'), new_nav_item: settings_nav_item)
      insert_after_nav_item(_('Settings'), new_nav_item: administration_nav_item)

      visit group_path(group)
    end

    it_behaves_like 'verified navigation bar'
  end

  context 'when packages are available' do
    before do
      stub_config(packages: { enabled: true }, registry: { enabled: false })
      stub_licensed_features(packages: true)

      insert_after_nav_item(
        _('Kubernetes'),
        new_nav_item: {
          nav_item: _('Packages & Registries'),
          nav_sub_items: [_('Package Registry')]
        }
      )
      visit group_path(group)
    end

    it_behaves_like 'verified navigation bar'

    context 'when container registry is available' do
      before do
        stub_config(registry: { enabled: true })

        insert_after_sub_nav_item(
          _('Package Registry'),
          within: _('Packages & Registries'),
          new_sub_nav_item_name: _('Container Registry')
        )

        visit group_path(group)
      end

      it_behaves_like 'verified navigation bar'
    end
  end

  context 'when push_rules for groups are available' do
    before do
      group.add_owner(user)

      stub_feature_flags(group_push_rules: true)

      insert_after_nav_item(
        _('Merge Requests'),
        new_nav_item: {
          nav_item: _('Push Rules'),
          nav_sub_items: []
        }
      )

      insert_after_nav_item(_('Members'), new_nav_item: settings_nav_item)
      insert_after_nav_item(_('Settings'), new_nav_item: administration_nav_item)

      visit group_path(group)
    end

    it_behaves_like 'verified navigation bar'
  end

  context 'when iterations are available' do
    before do
      stub_licensed_features(iterations: true)
      stub_feature_flags(group_iterations: true)

      insert_after_sub_nav_item(
        _('Milestones'),
        within: _('Issues'),
        new_sub_nav_item_name: _('Iterations')
      )

      visit group_path(group)
    end

    it_behaves_like 'verified navigation bar'
  end
end
