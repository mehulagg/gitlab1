import Vue from 'vue';
import { GlToast } from '@gitlab/ui';
import ResetButton from './reset_button.vue';

Vue.use(GlToast);

export function pipelineMinutes() {
  const el = document.getElementById('pipeline-minutes-vue');

  if (el) {
    const { resetMinutesPath } = el.dataset;

    // eslint-disable-next-line no-new
    new Vue({
      el,
      provide: {
        resetMinutesPath,
      },
      render(createElement) {
        return createElement(ResetButton);
      },
    });
  }
}
