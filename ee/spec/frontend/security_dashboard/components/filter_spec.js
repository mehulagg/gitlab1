import { GlDropdown } from '@gitlab/ui';
import Filter from 'ee/security_dashboard/components/filter.vue';
import FilterOption from 'ee/security_dashboard/components/filters/filter_option.vue';
import { mount } from '@vue/test-utils';
import { trimText } from 'helpers/text_helper';

const generateOption = index => ({
  name: `Option ${index}`,
  id: `option-${index}`,
});

const generateOptions = length => {
  return Array.from({ length }).map((_, i) => generateOption(i));
};

describe('Filter component', () => {
  let wrapper;

  const createWrapper = propsData => {
    wrapper = mount(Filter, { propsData });
  };

  const findSearchInput = () =>
    wrapper.find({ ref: 'searchBox' }).exists() && wrapper.find({ ref: 'searchBox' }).find('input');
  const isDropdownOpen = () => wrapper.find(GlDropdown).classes('show');
  const dropdownItemsCount = () => wrapper.findAll(FilterOption).length;

  afterEach(() => {
    wrapper.destroy();
  });

  describe('severity', () => {
    let options;

    beforeEach(() => {
      options = generateOptions(8);
      const filter = {
        name: 'Severity',
        id: 'severity',
        options,
        selection: new Set([options[0].id, options[1].id, options[2].id]),
      };
      createWrapper({ filter });
    });

    it('should display all 8 severity options', () => {
      expect(dropdownItemsCount()).toEqual(8);
    });

    it('should display a check next to only the selected items', () => {
      expect(wrapper.findAll('[data-testid="mobile-issue-close-icon"]')).toHaveLength(3);
    });

    it('should correctly display the selected text', () => {
      const selectedText = trimText(wrapper.find('.dropdown-toggle').text());

      expect(selectedText).toBe(`${options[0].name} +2 more`);
    });

    it('should display "Severity" as the option name', () => {
      expect(wrapper.find('.js-name').text()).toContain('Severity');
    });

    it('should not have a search box', () => {
      expect(findSearchInput()).toBe(false);
    });

    it('should not be open', () => {
      expect(isDropdownOpen()).toBe(false);
    });

    describe('when the dropdown is open', () => {
      beforeEach(done => {
        wrapper.find('.dropdown-toggle').trigger('click');
        wrapper.vm.$root.$on('bv::dropdown::shown', () => done());
      });

      it('should keep the menu open after clicking on an item', async () => {
        expect(isDropdownOpen()).toBe(true);
        wrapper.find('.dropdown-item').trigger('click');
        await wrapper.vm.$nextTick();

        expect(isDropdownOpen()).toBe(true);
      });
    });
  });

  describe('Project', () => {
    describe('when there are lots of projects', () => {
      const LOTS = 30;

      beforeEach(() => {
        const options = generateOptions(LOTS);
        const filter = {
          name: 'Project',
          id: 'project',
          options,
          selection: new Set([options[0].id]),
        };

        createWrapper({ filter });
      });

      it('should display a search box', () => {
        expect(findSearchInput().exists()).toBe(true);
      });

      it(`should show all projects`, () => {
        expect(dropdownItemsCount()).toBe(LOTS);
      });

      it('should show only matching projects when a search term is entered', async () => {
        const input = findSearchInput();
        input.vm.$el.value = '0';
        input.vm.$el.dispatchEvent(new Event('input'));
        await wrapper.vm.$nextTick();

        expect(dropdownItemsCount()).toBe(3);
      });
    });
  });
});
