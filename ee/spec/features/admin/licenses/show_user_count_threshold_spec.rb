# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Display approaching user count limit banner', :js do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:license_seats_limit) { 10 }

  let_it_be(:license) do
    create(:license, data: build(:gitlab_license, restrictions: { active_user_count: license_seats_limit }).export)
  end

  shared_examples_for 'a visible banner' do
    it 'shows the banner' do
      visit root_dashboard_path

      expect(page).to have_content('Your instance is approaching its licensed user count')
      expect(page).to have_link('View users statistics', href: admin_users_path)
      expect(page).to have_link('Contact support', href: EE::CUSTOMER_LICENSE_SUPPORT_URL)
    end
  end

  shared_examples_for 'a hidden banner' do
    it 'does not show the banner' do
      visit root_dashboard_path

      expect(page).not_to have_content('Your instance is approaching its licensed user count')
      expect(page).not_to have_link('View users statistics', href: admin_users_path)
      expect(page).not_to have_link('Contact support', href: EE::CUSTOMER_LICENSE_SUPPORT_URL)
    end
  end

  before do
    create(:historical_data, date: license.created_at + 1.month, active_user_count: active_user_count)
  end

  context 'with reached user count threshold' do
    let(:active_user_count) { license_seats_limit - 1 }

    context 'when admin is logged in' do
      before do
        gitlab_sign_in(admin)
      end

      it_behaves_like 'a visible banner'

      context 'when banner was dismissed' do
        before do
          visit root_dashboard_path

          find('.gl-alert-dismiss').click
        end

        it_behaves_like 'a hidden banner'
      end
    end

    context 'when regular user is logged in' do
      before do
        gitlab_sign_in(user)
      end

      it_behaves_like 'a hidden banner'
    end
  end

  context 'when not reached user count threshold' do
    let(:active_user_count) { 1 }

    context 'when admin is logged in' do
      before do
        gitlab_sign_in(admin)
      end

      it_behaves_like 'a hidden banner'
    end

    context 'when regular user is logged in' do
      before do
        gitlab_sign_in(user)
      end

      it_behaves_like 'a hidden banner'
    end
  end

  context 'when active user count is above license user count' do
    let(:active_user_count) { license_seats_limit + 2 }

    before do
      gitlab_sign_in(admin)
    end

    it_behaves_like 'a hidden banner'
  end

  context 'without license' do
    let(:active_user_count) { license_seats_limit }

    before do
      allow(License).to receive(:current).and_return(nil)
    end

    it_behaves_like 'a hidden banner'
  end

  context 'with trial license' do
    let(:active_user_count) { license_seats_limit }

    before do
      allow(License).to receive(:trial?).and_return(true)
    end

    it_behaves_like 'a hidden banner'
  end
end
