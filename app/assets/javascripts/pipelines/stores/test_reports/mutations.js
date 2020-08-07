import * as types from './mutation_types';

export default {
  [types.SET_SUITE](state, { suite = {}, index = null }) {
    state.testReports.test_suites[index] = { ...suite, hasFullSuite: true };
  },

  [types.SET_SELECTED_SUITE_INDEX](state, selectedSuiteIndex) {
    Object.assign(state, { selectedSuiteIndex });
  },

  [types.SET_SUMMARY](state, testReports) {
    Object.assign(state, { testReports });
  },

  [types.TOGGLE_LOADING](state) {
    Object.assign(state, { isLoading: !state.isLoading });
  },
};
