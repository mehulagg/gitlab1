import { GlEmptyState, GlLoadingIcon, GlAlert } from '@gitlab/ui';
import { createLocalVue, shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import AddScheduleModal from 'ee/oncall_schedules/components/add_edit_schedule_modal.vue';
import OnCallSchedule from 'ee/oncall_schedules/components/oncall_schedule.vue';
import OnCallScheduleWrapper, {
  i18n,
} from 'ee/oncall_schedules/components/oncall_schedules_wrapper.vue';
import getOncallSchedulesWithRotationsQuery from 'ee/oncall_schedules/graphql/queries/get_oncall_schedules.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { preExistingSchedule, newlyCreatedSchedule } from './mocks/apollo_mock';

const localVue = createLocalVue();

describe('On-call schedule wrapper', () => {
  let wrapper;
  const emptyOncallSchedulesSvgPath = 'illustration/path.svg';
  const projectPath = 'group/project';

  function mountComponent({ loading, schedules, multipleOncallSchedules = false } = {}) {
    const $apollo = {
      queries: {
        schedules: {
          loading,
        },
      },
    };

    wrapper = shallowMount(OnCallScheduleWrapper, {
      data() {
        return {
          schedules,
        };
      },
      provide: {
        emptyOncallSchedulesSvgPath,
        projectPath,
        glFeatures: { multipleOncallSchedules },
      },
      mocks: { $apollo },
    });
  }

  let getOncallSchedulesQuerySpy;

  function mountComponentWithApollo() {
    const fakeApollo = createMockApollo([
      [getOncallSchedulesWithRotationsQuery, getOncallSchedulesQuerySpy],
    ]);
    localVue.use(VueApollo);

    wrapper = shallowMount(OnCallScheduleWrapper, {
      localVue,
      apolloProvider: fakeApollo,
      data() {
        return {
          schedule: {},
        };
      },
      provide: {
        emptyOncallSchedulesSvgPath,
        projectPath,
      },
    });
  }

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  const findLoader = () => wrapper.findComponent(GlLoadingIcon);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findSchedules = () => wrapper.findAllComponents(OnCallSchedule);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findModal = () => wrapper.findComponent(AddScheduleModal);

  it('shows a loader while data is requested', () => {
    mountComponent({ loading: true });
    expect(findLoader().exists()).toBe(true);
  });

  it('shows empty state and passed correct attributes to it when not loading and no schedule', () => {
    mountComponent({ loading: false, schedules: [] });
    const emptyState = findEmptyState();

    expect(emptyState.exists()).toBe(true);
    expect(emptyState.attributes()).toEqual({
      title: i18n.emptyState.title,
      svgpath: emptyOncallSchedulesSvgPath,
      description: i18n.emptyState.description,
    });
  });

  describe('Schedule created', () => {
    beforeEach(() => {
      mountComponent({ loading: false, schedules: [{ name: 'monitor rotation' }] });
    });

    it('renders the schedule when data received ', () => {
      const schedule = findSchedules().at(0);
      expect(findLoader().exists()).toBe(false);
      expect(findEmptyState().exists()).toBe(false);
      expect(schedule.exists()).toBe(true);
    });

    it('shows success alert', async () => {
      await findModal().vm.$emit('scheduleCreated');
      const alert = findAlert();
      expect(alert.exists()).toBe(true);
      expect(alert.props('title')).toBe(i18n.successNotification.title);
      expect(alert.text()).toBe(i18n.successNotification.description);
    });

    it('renders a newly created schedule', async () => {
      const schedule = findSchedules().at(0);
      await findModal().vm.$emit('scheduleCreated');
      expect(schedule.exists()).toBe(true);
    });
  });

  describe('Apollo', () => {
    beforeEach(() => {
      getOncallSchedulesQuerySpy = jest.fn().mockResolvedValue({
        data: {
          project: {
            incidentManagementOncallSchedules: {
              nodes: [preExistingSchedule, newlyCreatedSchedule],
            },
          },
        },
      });
    });

    it('should render newly created schedule', async () => {
      mountComponentWithApollo();
      jest.runOnlyPendingTimers();
      await wrapper.vm.$nextTick();
      const schedule = findSchedules().at(0);
      expect(schedule.props('schedule')).toEqual(newlyCreatedSchedule);
    });
  });

  describe('when multiple schedules are allowed to be shown', () => {
    beforeEach(() => {
      mountComponent({
        loading: false,
        schedules: [{ name: 'monitor rotation' }, { name: 'monitor rotation 2' }],
        multipleOncallSchedules: true,
      });
    });

    it('renders the schedules when data received ', () => {
      expect(findLoader().exists()).toBe(false);
      expect(findEmptyState().exists()).toBe(false);
      expect(findSchedules()).toHaveLength(2);
    });
  });
});
