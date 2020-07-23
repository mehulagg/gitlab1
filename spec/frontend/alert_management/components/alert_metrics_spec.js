import { shallowMount } from '@vue/test-utils';
import waitForPromises from 'helpers/wait_for_promises';
import AlertMetrics from '~/alert_management/components/alert_metrics.vue';
import MockAdapter from 'axios-mock-adapter';
import axios from 'axios';

jest.mock('~/monitoring/stores', () => ({
  monitoringDashboard: {},
}));

const mockEmbedName = 'MetricsEmbedStub';

jest.mock('~/monitoring/components/embeds/metric_embed.vue', () => ({
  name: mockEmbedName,
  render(h) {
    return h('div');
  },
}));

describe('Alert Metrics', () => {
  let wrapper;
  const mock = new MockAdapter(axios);

  function mountComponent({ props } = {}) {
    wrapper = shallowMount(AlertMetrics, {
      propsData: {
        ...props,
      },
      stubs: {
        MetricEmbed: true,
      },
    });
  }

  const findChart = () => wrapper.find({ name: mockEmbedName });
  const findEmptyState = () => wrapper.find({ ref: 'emptyState' });

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  afterAll(() => {
    mock.restore();
  });

  describe('Empty state', () => {
    it('should display a message when metrics dashboard url is not provided ', () => {
      mountComponent();
      expect(findChart().exists()).toBe(false);
      expect(findEmptyState().text()).toBe("Metrics weren't available in the alerts payload.");
    });
  });

  describe('Chart', () => {
    it('should be rendered when dashboard url is provided', async () => {
      mountComponent({ props: { dashboardUrl: 'metrics.url' } });

      await waitForPromises();
      await wrapper.vm.$nextTick();

      expect(findEmptyState().exists()).toBe(false);
      expect(findChart().exists()).toBe(true);
    });
  });
});
