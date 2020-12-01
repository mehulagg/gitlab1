import Vue from 'vue';
import IntegrationForm from './components/integration_form.vue';

export default (el, store) => {
  if (!el) {
    return null;
  }

  return new Vue({
    el,
    store,
    render(createElement) {
      return createElement(IntegrationForm);
    },
  });
};
