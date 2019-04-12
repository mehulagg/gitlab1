import Vue from 'vue';
import { mapActions } from 'vuex';
import store from './store';
import LicenseCardsList from './components/license_cards_list.vue';

export default function mountInstanceLicenseApp(mountElement) {
  if (!mountElement) return undefined;

  const {
    currentActiveUserCount,
    licensesPath,
    deleteLicensePath,
    newLicensePath,
    downloadLicensePath,
  } = mountElement.dataset;

  return new Vue({
    el: mountElement,
    store,
    created() {
      this.setInitialData({
        licensesPath,
        deleteLicensePath,
        newLicensePath,
        downloadLicensePath,
        currentActiveUserCount: parseInt(currentActiveUserCount, 10),
      });

      this.fetchLicenses();
    },
    methods: {
      ...mapActions(['setInitialData', 'fetchLicenses']),
    },
    render(createElement) {
      return createElement(LicenseCardsList);
    },
  });
}
