import { mount } from '@vue/test-utils';
import { GlPagination, GlTable } from '@gitlab/ui';
import useWindowLocation from 'helpers/set_window_location_helper';

import AuditEventsTable from 'ee/audit_events/components/audit_events_table.vue';
import createEvents from '../mock_data';

const EVENTS = createEvents();

describe('AuditEventsTable component', () => {
  useWindowLocation();

  let wrapper;

  const createComponent = (props = {}) => {
    return mount(AuditEventsTable, {
      propsData: {
        events: EVENTS,
        isLastPage: false,
        ...props,
      },
    });
  };

  const getCell = (trIdx, tdIdx) => {
    return wrapper
      .find(GlTable)
      .find('tbody')
      .findAll('tr')
      .at(trIdx)
      .findAll('td')
      .at(tdIdx);
  };

  beforeEach(() => {
    window.location.href = 'https://localhost';

    wrapper = createComponent();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('Table behaviour', () => {
    it('should show', () => {
      expect(getCell(0, 1).text()).toBe('User');
    });

    it('should show the empty state if there is no data', () => {
      wrapper.setProps({ events: [] });
      wrapper.vm.$nextTick(() => {
        expect(getCell(0, 0).text()).toBe('There are no records to show');
      });
    });

    it('should not set the QA selector if not provided', () => {
      wrapper.vm.$nextTick(() => {
        expect(
          wrapper.find('[data-testid="audit-events-table"]').attributes('data-qa-selector'),
        ).toBeUndefined();
      });
    });

    it('should set the QA selector if provided', () => {
      wrapper.setProps({ qaSelector: 'qa_selector' });
      wrapper.vm.$nextTick(() => {
        expect(
          wrapper.find('[data-testid="audit-events-table"]').attributes('data-qa-selector'),
        ).toEqual('qa_selector');
      });
    });
  });

  describe('Pagination behaviour', () => {
    it('should show', () => {
      expect(wrapper.find(GlPagination).exists()).toBe(true);
    });

    it('should hide if there is no data', () => {
      wrapper.setProps({ events: [] });
      wrapper.vm.$nextTick(() => {
        expect(wrapper.find(GlPagination).exists()).toBe(false);
      });
    });

    it('should get the page number from the URL', () => {
      window.location.search = '?page=2';
      wrapper = createComponent();

      expect(wrapper.find(GlPagination).props().value).toBe(2);
    });

    it('should not have a prevPage if the page is 1', () => {
      window.location.search = '?page=1';
      wrapper = createComponent();

      expect(wrapper.find(GlPagination).props().prevPage).toBe(null);
    });

    it('should set the prevPage to 1 if the page is 2', () => {
      window.location.search = '?page=2';
      wrapper = createComponent();

      expect(wrapper.find(GlPagination).props().prevPage).toBe(1);
    });

    it('should not have a nextPage if isLastPage is true', () => {
      wrapper.setProps({ isLastPage: true });
      wrapper.vm.$nextTick(() => {
        expect(wrapper.find(GlPagination).props().nextPage).toBe(null);
      });
    });

    it('should set the nextPage to 2 if the page is 1', () => {
      window.location.search = '?page=1';
      wrapper = createComponent();

      expect(wrapper.find(GlPagination).props().nextPage).toBe(2);
    });

    it('should set the nextPage to 2 if the page is not set', () => {
      expect(wrapper.find(GlPagination).props().nextPage).toBe(2);
    });
  });
});
