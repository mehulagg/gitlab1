import Vue from 'vue';
import Translate from '~/vue_shared/translate';
import createStore from './store';
import GeoDesignsApp from './components/app.vue';

Vue.use(Translate);

export default () => {
  const el = document.getElementById('js-geo-designs');

  return new Vue({
    el,
    store: createStore(),
    components: {
      GeoDesignsApp,
    },
    data() {
      const {
        dataset: { geoSvgPath, geoTroubleshootingLink, designManagementLink, designsEnabled },
      } = this.$options.el;

      return {
        geoSvgPath,
        geoTroubleshootingLink,
        designManagementLink,
        designsEnabled,
      };
    },

    render(createElement) {
      return createElement('geo-designs-app', {
        props: {
          geoSvgPath: this.geoSvgPath,
          geoTroubleshootingLink: this.geoTroubleshootingLink,
          designManagementLink: this.designManagementLink,
          designsEnabled: this.designsEnabled,
        },
      });
    },
  });
};
