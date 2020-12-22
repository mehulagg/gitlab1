import Vuex from 'vuex';
import { mount, createLocalVue } from '@vue/test-utils';

import RoadmapShell from 'ee/roadmap/components/roadmap_shell.vue';
import { PRESET_TYPES } from 'ee/roadmap/constants';
import eventHub from 'ee/roadmap/event_hub';
import createStore from 'ee/roadmap/store';
import { getTimeframeForMonthsView } from 'ee/roadmap/utils/roadmap_utils';

import {
  mockEpic,
  mockTimeframeInitialDate,
  mockGroupId,
  mockMilestone,
} from 'ee_jest/roadmap/mock_data';

const mockTimeframeMonths = getTimeframeForMonthsView(mockTimeframeInitialDate);

describe('RoadmapShell', () => {
  const localVue = createLocalVue();
  localVue.use(Vuex);

  let store;
  let wrapper;

  const storeFactory = ({ defaultInnerHeight = 0 }) => {
    store = createStore();
    store.dispatch('setInitialData', {
      defaultInnerHeight,
      childrenFlags: { 1: { itemExpanded: false } },
    });
  };

  const createComponent = (
    {
      epics = [mockEpic],
      milestones = [mockMilestone],
      timeframe = mockTimeframeMonths,
      currentGroupId = mockGroupId,
      hasFiltersApplied = false,
    },
    el,
  ) => {
    wrapper = mount(RoadmapShell, {
      localVue,
      store,
      attachTo: el,
      propsData: {
        presetType: PRESET_TYPES.MONTHS,
        epics,
        milestones,
        timeframe,
        currentGroupId,
        hasFiltersApplied,
      },
    });
  };

  beforeEach(() => {
    storeFactory({});
    createComponent({});
  });

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
    store = null;
  });

  describe('data', () => {
    it('returns default data props', () => {
      expect(wrapper.vm.timeframeStartOffset).toBe(0);
    });
  });

  describe('methods', () => {
    beforeEach(() => {
      document.body.innerHTML +=
        '<div class="roadmap-container"><div data-testid="roadmap-shell"></div></div>';
      createComponent({}, document.querySelector('[data-testid="roadmap-shell"]'));
    });

    afterEach(() => {
      document.querySelector('.roadmap-container').remove();
    });

    describe('handleScroll', () => {
      it('emits `epicsListScrolled` event via eventHub', async () => {
        jest.spyOn(eventHub, '$emit').mockImplementation(() => {});

        await wrapper.vm.$nextTick();
        wrapper.vm.handleScroll();

        expect(eventHub.$emit).toHaveBeenCalledWith('epicsListScrolled', expect.any(Object));
      });
    });
  });

  describe('template', () => {
    it('renders component container element with class `js-roadmap-shell`', () => {
      expect(wrapper.find('.js-roadmap-shell').exists()).toBe(true);
    });
  });
});
