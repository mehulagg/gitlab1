import Vue from 'vue';
import * as types from './mutation_types';
import { parseIntPagination, normalizeHeaders } from '~/lib/utils/common_utils';
import { FEATURE_FLAG_SCOPE, USER_LIST_SCOPE } from '../../../constants';
import { mapToScopesViewModel } from '../helpers';

const mapFlag = flag => ({ ...flag, scopes: mapToScopesViewModel(flag.scopes || []) });

const updateFlag = (state, flag) => {
  const i = state[FEATURE_FLAG_SCOPE].findIndex(({ id }) => id === flag.id);
  Vue.set(state[FEATURE_FLAG_SCOPE], i, flag);
};

const setPaginationInfo = (state, scope, headers) => {
  let paginationInfo;
  if (Object.keys(headers).length) {
    const normalizedHeaders = normalizeHeaders(headers);
    paginationInfo = parseIntPagination(normalizedHeaders);
  } else {
    paginationInfo = headers;
  }
  Vue.set(state.count, scope, paginationInfo?.total ?? state[scope].length);
  Vue.set(state.pageInfo, scope, paginationInfo);
};

export default {
  [types.SET_FEATURE_FLAGS_ENDPOINT](state, endpoint) {
    state.endpoint = endpoint;
  },
  [types.SET_FEATURE_FLAGS_OPTIONS](state, options = {}) {
    state.options = options;
  },
  [types.SET_INSTANCE_ID_ENDPOINT](state, endpoint) {
    state.rotateEndpoint = endpoint;
  },
  [types.SET_INSTANCE_ID](state, instance) {
    state.instanceId = instance;
  },
  [types.SET_PROJECT_ID](state, project) {
    state.projectId = project;
  },
  [types.REQUEST_FEATURE_FLAGS](state) {
    state.isLoading = true;
  },
  [types.RECEIVE_FEATURE_FLAGS_SUCCESS](state, response) {
    state.isLoading = false;
    state.hasError = false;
    state[FEATURE_FLAG_SCOPE] = (response.data.feature_flags || []).map(mapFlag);

    setPaginationInfo(state, FEATURE_FLAG_SCOPE, response.headers);
  },
  [types.RECEIVE_FEATURE_FLAGS_ERROR](state) {
    state.isLoading = false;
    state.hasError = true;
  },
  [types.REQUEST_USER_LISTS](state) {
    state.isLoading = true;
  },
  [types.RECEIVE_USER_LISTS_SUCCESS](state, response) {
    state.isLoading = false;
    state.hasError = false;
    state[USER_LIST_SCOPE] = response.data || [];

    setPaginationInfo(state, USER_LIST_SCOPE, response.headers);
  },
  [types.RECEIVE_USER_LISTS_ERROR](state) {
    state.isLoading = false;
    state.hasError = true;
  },
  [types.REQUEST_ROTATE_INSTANCE_ID](state) {
    state.isRotating = true;
    state.hasRotateError = false;
  },
  [types.RECEIVE_ROTATE_INSTANCE_ID_SUCCESS](
    state,
    {
      data: { token },
    },
  ) {
    state.isRotating = false;
    state.instanceId = token;
    state.hasRotateError = false;
  },
  [types.RECEIVE_ROTATE_INSTANCE_ID_ERROR](state) {
    state.isRotating = false;
    state.hasRotateError = true;
  },
  [types.UPDATE_FEATURE_FLAG](state, flag) {
    updateFlag(state, flag);
  },
  [types.RECEIVE_UPDATE_FEATURE_FLAG_SUCCESS](state, data) {
    updateFlag(state, mapFlag(data));
  },
  [types.RECEIVE_UPDATE_FEATURE_FLAG_ERROR](state, i) {
    const flag = state[FEATURE_FLAG_SCOPE].find(({ id }) => i === id);
    updateFlag(state, { ...flag, active: !flag.active });
  },
  [types.REQUEST_DELETE_USER_LIST](state, list) {
    state.userLists = state.userLists.filter(l => l !== list);
  },
  [types.RECEIVE_DELETE_USER_LIST_ERROR](state, list) {
    state.isLoading = false;
    state.hasError = true;
    state.userLists = state.userLists.concat(list).sort((l1, l2) => l1.iid - l2.iid);
  },
};
