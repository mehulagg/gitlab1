import Vue from 'vue';
import CycleAnalytics from './components/base.vue';
import createStore from './store';

export default () => {
  const el = document.querySelector('#js-cycle-analytics-app');
  const { emptyStateSvgPath } = el.dataset;

  // eslint-disable-next-line no-new
  new Vue({
    el: '#js-cycle-analytics-app',
    name: 'CycleAnalyticsApp',
    store: createStore(),
    components: {
      CycleAnalytics,
    },
    render: createElement =>
      createElement(CycleAnalytics, {
        props: {
          emptyStateSvgPath,
        },
      }),
  });
};
