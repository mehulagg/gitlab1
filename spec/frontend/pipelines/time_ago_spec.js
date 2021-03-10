import { GlIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import TimeAgo from '~/pipelines/components/pipelines_list/time_ago.vue';

describe('Timeago component', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(TimeAgo, {
      propsData: {
        pipeline: {
          details: {
            ...props,
          },
        },
      },
      data() {
        return {
          iconTimerSvg: `<svg></svg>`,
        };
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  const duration = () => wrapper.find('.duration');
  const finishedAt = () => wrapper.find('.finished-at');
  const findInProgress = () => wrapper.find('[data-testid="pipeline-in-progress"]');

  describe('with duration', () => {
    beforeEach(() => {
      createComponent({ duration: 10, finished_at: '' });
    });

    it('should render duration and timer svg', () => {
      const icon = duration().find(GlIcon);

      expect(duration().exists()).toBe(true);
      expect(icon.props('name')).toBe('timer');
    });
  });

  describe('without duration', () => {
    beforeEach(() => {
      createComponent({ duration: 0, finished_at: '' });
    });

    it('should not render duration and timer svg', () => {
      expect(duration().exists()).toBe(false);
    });
  });

  describe('with finishedTime', () => {
    beforeEach(() => {
      createComponent({ duration: 0, finished_at: '2017-04-26T12:40:23.277Z' });
    });

    it('should render time and calendar icon', () => {
      const icon = finishedAt().find(GlIcon);
      const time = finishedAt().find('time');

      expect(finishedAt().exists()).toBe(true);
      expect(icon.props('name')).toBe('calendar');
      expect(time.exists()).toBe(true);
    });
  });

  describe('without finishedTime', () => {
    beforeEach(() => {
      createComponent({ duration: 0, finished_at: '' });
    });

    it('should not render time and calendar icon', () => {
      expect(finishedAt().exists()).toBe(false);
    });
  });

  describe('in progress', () => {
    it('shows in progress state when pipeline has not finished running', () => {
      createComponent({ duration: '', finished_at: '' });

      expect(findInProgress().exists()).toBe(true);
    });

    it('does not show in progress state when pipeline has finished running', () => {
      createComponent({ duration: 10, finished_at: '2017-04-26T12:40:23.277Z' });

      expect(findInProgress().exists()).toBe(false);
    });
  });
});
