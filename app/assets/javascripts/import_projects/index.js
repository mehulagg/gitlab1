import Vue from 'vue';
import { mapActions } from 'vuex';
import Translate from '../vue_shared/translate';
import ImportProjectsTable from './components/import_projects_table.vue';
import { parseBoolean } from '../lib/utils/common_utils';
import createStore from './store';

Vue.use(Translate);

export default function mountImportProjectsTable(mountElement) {
  if (!mountElement) return undefined;

  const {
    reposPath,
    provider,
    providerTitle,
    canSelectNamespace,
    jobsPath,
    importPath,
    ciCdOnly,
    filter,
  } = mountElement.dataset;

  const store = createStore();
  return new Vue({
    el: mountElement,
    store,

    created() {
      this.setInitialData({
        reposPath,
        provider,
        jobsPath,
        importPath,
        defaultTargetNamespace: gon.current_username,
        ciCdOnly: parseBoolean(ciCdOnly),
        canSelectNamespace: parseBoolean(canSelectNamespace),
        filter,
      });
    },

    methods: {
      ...mapActions(['setInitialData', 'setFilter']),
    },

    render(createElement) {
      return createElement(ImportProjectsTable, { props: { providerTitle } });
    },
  });
}
