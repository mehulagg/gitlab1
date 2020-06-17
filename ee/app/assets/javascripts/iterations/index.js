import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import Iterations from './components/iterations.vue';
import IterationForm from './components/iteration_form.vue';
import IterationReport from './components/iteration_report.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export function initIterationsList() {
  const el = document.querySelector('.js-iterations-list');

  return new Vue({
    el,
    apolloProvider,
    render(createElement) {
      return createElement(Iterations, {
        props: {
          groupPath: el.dataset.groupFullPath,
          canAdmin: parseBoolean(el.dataset.canAdmin),
          newIterationPath: el.dataset.newIterationPath,
        },
      });
    },
  });
}

export function initIterationForm() {
  const el = document.querySelector('.js-iteration-new');

  return new Vue({
    el,
    apolloProvider,
    render(createElement) {
      return createElement(IterationForm, {
        props: {
          groupPath: el.dataset.groupFullPath,
          previewMarkdownPath: el.dataset.previewMarkdownPath,
          iterationsListPath: el.dataset.iterationsListPath,
        },
      });
    },
  });
}

export function initIterationReport() {
  const el = document.querySelector('.js-iteration');

  const { groupPath, iterationId, editIterationPath } = el.dataset;
  const canEdit = parseBoolean(el.dataset.canEdit);

  return new Vue({
    el,
    apolloProvider,
    render(createElement) {
      return createElement(IterationReport, {
        props: {
          groupPath,
          iterationId,
          canEdit,
          editIterationPath,
        },
      });
    },
  });
}

export default {};
