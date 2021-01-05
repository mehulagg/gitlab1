import {
  GlButton,
  GlDropdown,
  GlDropdownItem,
  GlFormInput,
  GlSearchBoxByType,
  GlLoadingIcon,
} from '@gitlab/ui';
import { shallowMount, createLocalVue } from '@vue/test-utils';
import Vuex from 'vuex';

import CreateIssueForm from 'ee/related_items_tree/components/create_issue_form.vue';
import createDefaultStore from 'ee/related_items_tree/store';
import ProjectAvatar from '~/vue_shared/components/project_avatar/default.vue';

import { mockInitialConfig, mockParentItem } from '../mock_data';

const mockProjects = getJSONFixture('static/projects.json');

const localVue = createLocalVue();
localVue.use(Vuex);

const createComponent = () => {
  const store = createDefaultStore();

  store.dispatch('setInitialConfig', mockInitialConfig);
  store.dispatch('setInitialParentItem', mockParentItem);

  return shallowMount(CreateIssueForm, {
    localVue,
    store,
  });
};

describe('CreateIssueForm', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = createComponent();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('data', () => {
    it('initializes data props with default values', () => {
      expect(wrapper.vm.selectedProject).toBeNull();
      expect(wrapper.vm.searchKey).toBe('');
      expect(wrapper.vm.title).toBe('');
    });
  });

  describe('computed', () => {
    describe('dropdownToggleText', () => {
      it('returns project name with namespace when `selectedProject` is not empty', () => {
        wrapper.setData({
          selectedProject: mockProjects[0],
        });

        return wrapper.vm.$nextTick(() => {
          expect(wrapper.vm.dropdownToggleText).toBe(mockProjects[0].name_with_namespace);
        });
      });
    });
  });

  describe('methods', () => {
    describe('cancel', () => {
      it('emits event `cancel` on component', () => {
        wrapper.vm.cancel();

        return wrapper.vm.$nextTick(() => {
          expect(wrapper.emitted('cancel')).toBeTruthy();
        });
      });
    });

    describe('createIssue', () => {
      it('emits event `submit` on component when `selectedProject` is not empty', () => {
        wrapper.setData({
          selectedProject: {
            ...mockProjects[0],
            _links: {
              issues: 'foo',
            },
          },
          title: 'Some issue',
        });

        wrapper.vm.createIssue();

        return wrapper.vm.$nextTick(() => {
          expect(wrapper.emitted('submit')[0]).toEqual(
            expect.arrayContaining([{ issuesEndpoint: 'foo', title: 'Some issue' }]),
          );
        });
      });
    });

    describe('handleDropdownShow', () => {
      it('sets `searchKey` prop to empty string and calls action `fetchProjects`', () => {
        const handleDropdownShow = jest
          .spyOn(wrapper.vm, 'fetchProjects')
          .mockImplementation(jest.fn());

        wrapper.vm.handleDropdownShow();

        expect(wrapper.vm.searchKey).toBe('');
        expect(handleDropdownShow).toHaveBeenCalled();
      });
    });
  });

  describe('templates', () => {
    it('renders Issue title input field', () => {
      const issueTitleFieldLabel = wrapper.findAll('label').at(0);
      const issueTitleFieldInput = wrapper.findComponent(GlFormInput);

      expect(issueTitleFieldLabel.text()).toBe('Title');
      expect(issueTitleFieldInput.attributes('placeholder')).toBe('New issue title');
    });

    it('renders Projects dropdown field', () => {
      const projectsDropdownLabel = wrapper.findAll('label').at(1);
      const projectsDropdownButton = wrapper.findComponent(GlDropdown);

      expect(projectsDropdownLabel.text()).toBe('Project');
      expect(projectsDropdownButton.props('text')).toBe('Select a project');
    });

    it('renders Projects dropdown contents', () => {
      wrapper.vm.$store.dispatch('receiveProjectsSuccess', mockProjects);

      return wrapper.vm.$nextTick(() => {
        const projectsDropdownButton = wrapper.findComponent(GlDropdown);
        const dropdownItems = projectsDropdownButton.findAllComponents(GlDropdownItem);
        const dropdownItem = dropdownItems.at(0);

        expect(projectsDropdownButton.findComponent(GlSearchBoxByType).exists()).toBe(true);
        expect(projectsDropdownButton.findComponent(GlLoadingIcon).exists()).toBe(true);
        expect(dropdownItems).toHaveLength(mockProjects.length);
        expect(dropdownItem.text()).toBe(mockProjects[0].name);
        expect(dropdownItem.attributes('secondarytext')).toBe(mockProjects[0].namespace.name);
        expect(dropdownItem.findComponent(ProjectAvatar).exists()).toBe(true);
      });
    });

    it('renders Projects dropdown contents containing only matching project when searchKey is provided', () => {
      const searchKey = 'Underscore';
      const filteredMockProjects = mockProjects.filter((project) => project.name === searchKey);
      jest.spyOn(wrapper.vm, 'fetchProjects').mockImplementation(jest.fn());

      wrapper.findComponent(GlDropdown).trigger('click');

      wrapper.setData({
        searchKey,
      });

      return wrapper.vm
        .$nextTick()
        .then(() => {
          wrapper.vm.$store.dispatch('receiveProjectsSuccess', filteredMockProjects);
        })
        .then(() => {
          expect(wrapper.findAllComponents(GlDropdownItem)).toHaveLength(1);
        });
    });

    it('renders Projects dropdown contents containing string string "No matches found" when searchKey provided does not match any project', () => {
      const searchKey = "this-project-shouldn't exist";
      const filteredMockProjects = mockProjects.filter((project) => project.name === searchKey);
      jest.spyOn(wrapper.vm, 'fetchProjects').mockImplementation(jest.fn());

      wrapper.findComponent(GlDropdown).trigger('click');

      wrapper.setData({
        searchKey,
      });

      return wrapper.vm
        .$nextTick()
        .then(() => {
          wrapper.vm.$store.dispatch('receiveProjectsSuccess', filteredMockProjects);
        })
        .then(() => {
          expect(wrapper.find('.dropdown-contents').text()).toContain('No matches found');
        });
    });

    it('renders `Create issue` button', () => {
      const createIssueButton = wrapper.findAllComponents(GlButton).at(0);

      expect(createIssueButton.exists()).toBe(true);
      expect(createIssueButton.text()).toBe('Create issue');
    });

    it('renders loading icon within `Create issue` button when `itemCreateInProgress` is true', () => {
      wrapper.vm.$store.dispatch('requestCreateItem');

      return wrapper.vm.$nextTick(() => {
        const createIssueButton = wrapper.findAllComponents(GlButton).at(0);

        expect(createIssueButton.exists()).toBe(true);
        expect(createIssueButton.props('disabled')).toBe(true);
        expect(createIssueButton.props('loading')).toBe(true);
      });
    });

    it('renders `Cancel` button', () => {
      const cancelButton = wrapper.findAllComponents(GlButton).at(1);

      expect(cancelButton.exists()).toBe(true);
      expect(cancelButton.text()).toBe('Cancel');
    });
  });
});
