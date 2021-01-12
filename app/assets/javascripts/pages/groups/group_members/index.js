import Vue from 'vue';
import memberExpirationDate from '~/member_expiration_date';
import UsersSelect from '~/users_select';
import groupsSelect from '~/groups_select';
import RemoveMemberModal from '~/vue_shared/components/remove_member_modal.vue';
import { initMembersApp } from '~/members/index';
import { groupMemberRequestFormatter } from '~/groups/members/utils';
import { groupLinkRequestFormatter } from '~/members/utils';
import { s__ } from '~/locale';

function mountRemoveMemberModal() {
  const el = document.querySelector('.js-remove-member-modal');
  if (!el) {
    return false;
  }

  return new Vue({
    el,
    render(createComponent) {
      return createComponent(RemoveMemberModal);
    },
  });
}

const SHARED_FIELDS = ['account', 'expires', 'maxRole', 'expiration', 'actions'];

initMembersApp(document.querySelector('.js-group-members-list'), {
  tableFields: SHARED_FIELDS.concat(['source', 'granted']),
  tableAttrs: { tr: { 'data-qa-selector': 'member_row' } },
  tableSortableFields: ['account', 'granted', 'maxRole', 'lastSignIn'],
  requestFormatter: groupMemberRequestFormatter,
  filteredSearchBar: {
    show: true,
    tokens: ['two_factor', 'with_inherited_permissions'],
    searchParam: 'search',
    placeholder: s__('Members|Filter members'),
    recentSearchesStorageKey: 'group_members',
  },
});

initMembersApp(document.querySelector('.js-group-group-links-list'), {
  tableFields: SHARED_FIELDS.concat('granted'),
  tableAttrs: {
    table: { 'data-qa-selector': 'groups_list' },
    tr: { 'data-qa-selector': 'group_row' },
  },
  requestFormatter: groupLinkRequestFormatter,
});
initMembersApp(document.querySelector('.js-group-invited-members-list'), {
  tableFields: SHARED_FIELDS.concat('invited'),
  requestFormatter: groupMemberRequestFormatter,
  filteredSearchBar: {
    show: true,
    tokens: [],
    searchParam: 'search_invited',
    placeholder: s__('Members|Search invited'),
    recentSearchesStorageKey: 'group_invited_members',
  },
});
initMembersApp(document.querySelector('.js-group-access-requests-list'), {
  tableFields: SHARED_FIELDS.concat('requested'),
  requestFormatter: groupMemberRequestFormatter,
});

groupsSelect();
memberExpirationDate();
memberExpirationDate('.js-access-expiration-date-groups');
mountRemoveMemberModal();

new UsersSelect(); // eslint-disable-line no-new
