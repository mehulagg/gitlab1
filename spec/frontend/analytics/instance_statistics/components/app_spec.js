import { shallowMount } from '@vue/test-utils';
import InstanceStatisticsApp from '~/analytics/instance_statistics/components/app.vue';
import InstanceCounts from '~/analytics/instance_statistics/components//instance_counts.vue';
import InstanceStatisticsCountChart from '~/analytics/instance_statistics/components/instance_statistics_count_chart.vue';

describe('InstanceStatisticsApp', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(InstanceStatisticsApp);
  };

  beforeEach(() => {
    createComponent();
  });

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  it('displays the instance counts component', () => {
    expect(wrapper.find(InstanceCounts).exists()).toBe(true);
  });

  it('displays the instance statistics count chart component', () => {
    const allCharts = wrapper.findAll(InstanceStatisticsCountChart);
    expect(allCharts).toHaveLength(2);
    expect(allCharts.at(0).exists()).toBe(true);
    expect(allCharts.at(1).exists()).toBe(true);
  });
});
