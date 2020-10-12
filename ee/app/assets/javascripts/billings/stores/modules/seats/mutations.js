import * as types from './mutation_types';
import {
  HEADER_TOTAL_ENTRIES,
  HEADER_PAGE_NUMBER,
  HEADER_ITEMS_PER_PAGE,
} from '../../../constants';

export default {
  [types.SET_NAMESPACE_ID](state, payload) {
    state.namespaceId = payload;
  },

  [types.REQUEST_BILLABLE_MEMBERS](state) {
    state.isLoading = true;
    state.hasError = false;
  },

  [types.RECEIVE_BILLABLE_MEMBERS_SUCCESS](state, payload) {
    const { data, headers } = payload;

    state.members = data;

    state.total = headers[HEADER_TOTAL_ENTRIES];
    state.page = headers[HEADER_PAGE_NUMBER];
    state.perPage = headers[HEADER_ITEMS_PER_PAGE];

    state.isLoading = false;
  },

  [types.RECEIVE_BILLABLE_MEMBERS_ERROR](state) {
    state.isLoading = false;
    state.hasError = true;
  },
};
