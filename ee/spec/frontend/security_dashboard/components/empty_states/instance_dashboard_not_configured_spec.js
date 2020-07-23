import { mount } from '@vue/test-utils';
import { GlEmptyState, GlButton, GlLink } from '@gitlab/ui';
import DashboardNotConfigured from 'ee/security_dashboard/components/empty_states/instance_dashboard_not_configured.vue';

describe('first class instance security dashboard empty state', () => {
  let wrapper;
  const dashboardDocumentation = '/path/to/dashboard/documentation';
  const emptyStateSvgPath = '/placeholder.svg';

  const createWrapper = () =>
    mount(DashboardNotConfigured, {
      provide: {
        dashboardDocumentation,
        emptyStateSvgPath,
      },
    });

  const findGlEmptyState = () => wrapper.find(GlEmptyState);
  const findButton = () => wrapper.find(GlButton);
  const findLink = () => wrapper.find(GlLink);

  beforeEach(() => {
    wrapper = createWrapper();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  it('contains a GlEmptyState', () => {
    expect(findGlEmptyState().exists()).toBe(true);
    expect(findGlEmptyState().props('svgPath')).toBe(emptyStateSvgPath);
  });

  it('contains a GlLink with href attribute equal to dashboardDocumentation', () => {
    expect(findLink().attributes('href')).toBe(dashboardDocumentation);
  });

  it('contains a GlButton', () => {
    expect(findButton().exists()).toBe(true);
  });

  it('emits `handleAddProjectsClick` on button click', async () => {
    const eventName = 'handleAddProjectsClick';

    findButton().trigger('click');
    await wrapper.vm.$nextTick();

    expect(wrapper.emitted()).toHaveProperty(eventName);
  });
});
