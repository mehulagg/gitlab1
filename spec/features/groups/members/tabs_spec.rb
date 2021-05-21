# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Members > Tabs', :js do
  using RSpec::Parameterized::TableSyntax

  shared_examples 'active "Members" tab' do
    it 'displays "Members" tab' do
      expect(page).to have_selector('.nav-link.active', text: 'Members')
    end
  end

  shared_examples 'active "Invited" tab' do
    it 'displays "Invited" tab' do
      expect(page).to have_selector('.nav-link.active', text: 'Invited')
    end
  end

  let(:owner) { create(:user) }
  let(:group) { create(:group) }

  before do
    stub_const('Groups::GroupMembersController::MEMBER_PER_PAGE_LIMIT', 1)
    allow_any_instance_of(Member).to receive(:send_request).and_return(true)

    group.add_owner(owner)
    sign_in(owner)

    create_list(:group_member, 2, group: group)
    create_list(:group_member, 2, :invited, group: group)
    create_list(:group_group_link, 2, shared_group: group)
    create_list(:group_member, 2, :access_request, group: group)
  end

  where(:tab, :count) do
    'Members'         | 3
    'Invited'         | 2
    'Groups'          | 2
    'Access requests' | 2
  end

  with_them do
    it "renders #{params[:tab]} tab" do
      visit group_group_members_path(group)

      expect(page).to have_selector('.nav-link', text: "#{tab} #{count}")
    end
  end

  context 'displays "Members" tab by default' do
    before do
      visit group_group_members_path(group)
    end

    it_behaves_like 'active "Members" tab'
  end

  context 'when searching "Invited"' do
    before do
      visit group_group_members_path(group)

      click_link 'Invited'

      page.within '[data-testid="members-filtered-search-bar"]' do
        find_field('Search invited').click
        find('input').native.send_keys('email')
        click_button 'Search'
      end
    end

    it_behaves_like 'active "Invited" tab'

    context 'and then searching "Members"' do
      before do
        click_link 'Members'

        page.within '[data-testid="members-filtered-search-bar"]' do
          find_field('Filter members').click
          find('input').native.send_keys('test')
          click_button 'Search'
        end
      end

      it_behaves_like 'active "Members" tab'
    end
  end

  context 'when using "Invited" pagination' do
    before do
      visit group_group_members_path(group)

      click_link 'Invited'

      page.within '.pagination' do
        click_link '2'
      end
    end

    it_behaves_like 'active "Invited" tab'

    context 'and then using "Members" pagination' do
      before do
        click_link 'Members'

        page.within '.pagination' do
          click_link '2'
        end
      end

      it_behaves_like 'active "Members" tab'
    end
  end
end
