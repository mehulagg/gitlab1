import Vue from 'vue';
import * as types from './mutation_types';
import CEMutations from '~/vuex_shared/modules/members/mutations';
import { s__ } from '~/locale';
import { findMember } from '~/vuex_shared/modules/members/utils';

export default {
  ...CEMutations,
  [types.RECEIVE_LDAP_OVERRIDE_SUCCESS](state, { memberId, override }) {
    const member = findMember(state, memberId);

    if (!member) {
      return;
    }

    Vue.set(member, 'isOverridden', override);
  },
  [types.RECEIVE_LDAP_OVERRIDE_ERROR](state, override) {
    if (override) {
      state.errorMessage = s__(
        'Members|An error occurred while trying to enable LDAP override, please try again.',
      );
    } else {
      state.errorMessage = s__(
        'Members|An error occurred while trying to revert to LDAP group sync settings, please try again.',
      );
    }
    state.showError = true;
  },
  [types.SHOW_LDAP_OVERRIDE_CONFIRMATION_MODAL](state, member) {
    state.ldapOverrideConfirmationModalVisible = true;
    state.memberToOverride = member;
  },
  [types.HIDE_LDAP_OVERRIDE_CONFIRMATION_MODAL](state) {
    state.ldapOverrideConfirmationModalVisible = false;
  },
};
