import Vue from 'vue';
import Flash from '~/flash';
import Translate from '~/vue_shared/translate';
import { __ } from '~/locale';
import PipelinesMediator from 'ee/pipelines/pipeline_details_mediator';
import pipelineGraph from './components/graph/graph_component.vue';
import pipelineHeader from './components/header_component.vue';
import eventHub from './event_hub';
import GraphEEMixin from 'ee/pipelines/mixins/graph_pipeline_bundle_mixin'; // eslint-disable-line import/order

Vue.use(Translate);

export default () => {
  const { dataset } = document.querySelector('.js-pipeline-details-vue');

  const mediator = new PipelinesMediator({ endpoint: dataset.endpoint });

  mediator.fetchPipeline();

  // eslint-disable-next-line
  new Vue({
    el: '#js-pipeline-graph-vue',
    components: {
      pipelineGraph,
    },
    mixins: [GraphEEMixin],
    data() {
      return {
        mediator,
      };
    },
    methods: {
      requestRefreshPipelineGraph() {
        // When an action is clicked
        // (wether in the dropdown or in the main nodes, we refresh the big graph)
        this.mediator
          .refreshPipeline()
          .catch(() => Flash(__('An error occurred while making the request.')));
      },
    },
    render(createElement) {
      return createElement('pipeline-graph', {
        props: {
          isLoading: this.mediator.state.isLoading,
          pipeline: this.mediator.store.state.pipeline,
        },
        on: {
          refreshPipelineGraph: this.requestRefreshPipelineGraph,
          // EE-only start
          onClickPipeline: (key, parentId, pipeline) => this.clickPipeline(key, pipeline),
          // EE-only end
        },
      });
    },
  });

  // eslint-disable-next-line
  new Vue({
    el: '#js-pipeline-header-vue',
    components: {
      pipelineHeader,
    },
    data() {
      return {
        mediator,
      };
    },
    created() {
      eventHub.$on('headerPostAction', this.postAction);
    },
    beforeDestroy() {
      eventHub.$off('headerPostAction', this.postAction);
    },
    methods: {
      postAction(action) {
        this.mediator.service
          .postAction(action.path)
          .then(() => this.mediator.refreshPipeline())
          .catch(() => Flash(__('An error occurred while making the request.')));
      },
    },
    render(createElement) {
      return createElement('pipeline-header', {
        props: {
          isLoading: this.mediator.state.isLoading,
          pipeline: this.mediator.store.state.pipeline,
        },
      });
    },
  });
};
