import { shallowMount } from '@vue/test-utils';
import { GlLoadingIcon } from '@gitlab/ui';

import { mockCurrentUserTodo } from 'jest/issuable_list/mock_data';

import TestCaseShowRoot from 'ee/test_case_show/components/test_case_show_root.vue';
import TestCaseSidebar from 'ee/test_case_show/components/test_case_sidebar.vue';

import IssuableShow from '~/issuable_show/components/issuable_show_root.vue';
import IssuableHeader from '~/issuable_show/components/issuable_header.vue';
import IssuableBody from '~/issuable_show/components/issuable_body.vue';
import IssuableEditForm from '~/issuable_show/components/issuable_edit_form.vue';
import IssuableSidebar from '~/issuable_sidebar/components/issuable_sidebar_root.vue';
import IssuableEventHub from '~/issuable_show/event_hub';

import { mockProvide, mockTestCase } from '../mock_data';

const createComponent = ({ testCase, testCaseQueryLoading = false } = {}) =>
  shallowMount(TestCaseShowRoot, {
    provide: {
      ...mockProvide,
    },
    mocks: {
      $apollo: {
        queries: {
          testCase: {
            loading: testCaseQueryLoading,
            refetch: jest.fn(),
          },
        },
      },
    },
    stubs: {
      IssuableShow,
      IssuableHeader,
      IssuableBody,
      IssuableEditForm,
      IssuableSidebar,
    },
    data() {
      return {
        testCaseLoading: testCaseQueryLoading,
        testCase: testCaseQueryLoading
          ? {}
          : {
              ...mockTestCase,
              ...testCase,
            },
      };
    },
  });

describe('TestCaseShowRoot', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = createComponent();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('computed', () => {
    describe.each`
      state       | isTestCaseOpen | statusBadgeClass             | statusIcon              | statusBadgeText | testCaseActionButtonVariant | testCaseActionTitle
      ${'opened'} | ${true}        | ${'status-box-open'}         | ${'issue-open-m'}       | ${'Open'}       | ${'warning'}                | ${'Archive test case'}
      ${'closed'} | ${false}       | ${'status-box-issue-closed'} | ${'mobile-issue-close'} | ${'Archived'}   | ${'default'}                | ${'Reopen test case'}
    `(
      'when `testCase.state` is $state',
      ({
        state,
        isTestCaseOpen,
        statusBadgeClass,
        statusIcon,
        statusBadgeText,
        testCaseActionButtonVariant,
        testCaseActionTitle,
      }) => {
        beforeEach(async () => {
          wrapper.setData({
            testCase: {
              ...mockTestCase,
              state,
            },
          });

          await wrapper.vm.$nextTick();
        });

        it.each`
          propName                         | propValue
          ${'isTestCaseOpen'}              | ${isTestCaseOpen}
          ${'statusBadgeClass'}            | ${statusBadgeClass}
          ${'statusIcon'}                  | ${statusIcon}
          ${'statusBadgeText'}             | ${statusBadgeText}
          ${'testCaseActionButtonVariant'} | ${testCaseActionButtonVariant}
          ${'testCaseActionTitle'}         | ${testCaseActionTitle}
        `('computed prop $propName returns $propValue', ({ propName, propValue }) => {
          expect(wrapper.vm[propName]).toBe(propValue);
        });
      },
    );

    describe('todo', () => {
      it('returns first todo object from `testCase.currentUserTodos.nodes` array', () => {
        expect(wrapper.vm.todo).toBe(mockCurrentUserTodo);
      });
    });

    describe('selectedLabels', () => {
      it('returns `testCase.labels.nodes` array with GraphQL IDs converted to numeric IDs', () => {
        mockTestCase.labels.nodes.forEach((label, index) => {
          expect(label.id.endsWith(`${wrapper.vm.selectedLabels[index].id}`)).toBe(true);
        });
      });
    });
  });

  describe('methods', () => {
    describe('handleTestCaseStateChange', () => {
      const updateTestCase = {
        ...mockTestCase,
        state: 'closed',
      };

      beforeEach(() => {
        jest.spyOn(wrapper.vm, 'updateTestCase').mockResolvedValue(updateTestCase);
      });

      it('sets `testCaseStateChangeInProgress` prop to true', () => {
        wrapper.vm.handleTestCaseStateChange();

        expect(wrapper.vm.testCaseStateChangeInProgress).toBe(true);
      });

      it('calls `wrapper.vm.updateTestCase` with variable `stateEvent` and errorMessage string', () => {
        wrapper.vm.handleTestCaseStateChange();

        expect(wrapper.vm.updateTestCase).toHaveBeenCalledWith({
          variables: {
            stateEvent: 'CLOSE',
          },
          errorMessage: 'Something went wrong while updating the test case.',
        });
      });

      it('sets `testCase` prop with updated test case received in response', () => {
        return wrapper.vm.handleTestCaseStateChange().then(() => {
          expect(wrapper.vm.testCase).toBe(updateTestCase);
        });
      });

      it('sets `testCaseStateChangeInProgress` prop to false', () => {
        return wrapper.vm.handleTestCaseStateChange().then(() => {
          expect(wrapper.vm.testCaseStateChangeInProgress).toBe(false);
        });
      });
    });

    describe('handleEditTestCase', () => {
      it('sets `editTestCaseFormVisible` prop to true', () => {
        wrapper.vm.handleEditTestCase();

        expect(wrapper.vm.editTestCaseFormVisible).toBe(true);
      });
    });

    describe('handleSaveTestCase', () => {
      const updateTestCase = {
        ...mockTestCase,
        title: 'Foo',
        description: 'Bar',
      };

      beforeEach(() => {
        jest.spyOn(wrapper.vm, 'updateTestCase').mockResolvedValue(updateTestCase);
      });

      it('sets `testCaseSaveInProgress` prop to true', () => {
        wrapper.vm.handleSaveTestCase({
          issuableTitle: 'Foo',
          issuableDescription: 'Bar',
        });

        expect(wrapper.vm.testCaseSaveInProgress).toBe(true);
      });

      it('calls `wrapper.vm.updateTestCase` with variables `title` & `description` and errorMessage string', () => {
        wrapper.vm.handleSaveTestCase({
          issuableTitle: 'Foo',
          issuableDescription: 'Bar',
        });

        expect(wrapper.vm.updateTestCase).toHaveBeenCalledWith({
          variables: {
            title: 'Foo',
            description: 'Bar',
          },
          errorMessage: 'Something went wrong while updating the test case.',
        });
      });

      it('sets `testCase` prop with updated test case received in response and emits "update.issuable" on IssuableEventHub', () => {
        jest.spyOn(IssuableEventHub, '$emit').mockImplementation(jest.fn());

        return wrapper.vm
          .handleSaveTestCase({
            issuableTitle: 'Foo',
            issuableDescription: 'Bar',
          })
          .then(() => {
            expect(wrapper.vm.testCase).toBe(updateTestCase);
            expect(wrapper.vm.editTestCaseFormVisible).toBe(false);
            expect(IssuableEventHub.$emit).toHaveBeenCalledWith('update.issuable');
          });
      });

      it('sets `testCaseSaveInProgress` prop to false', () => {
        return wrapper.vm
          .handleSaveTestCase({
            issuableTitle: 'Foo',
            issuableDescription: 'Bar',
          })
          .then(() => {
            expect(wrapper.vm.testCaseSaveInProgress).toBe(false);
          });
      });
    });

    describe('handleCancelClick', () => {
      it('sets `editTestCaseFormVisible` prop to false and emits "close.form" even in IssuableEventHub', async () => {
        jest.spyOn(IssuableEventHub, '$emit').mockImplementation(jest.fn());
        wrapper.setData({
          editTestCaseFormVisible: true,
        });

        await wrapper.vm.$nextTick();

        wrapper.vm.handleCancelClick();

        expect(wrapper.vm.editTestCaseFormVisible).toBe(false);
        expect(IssuableEventHub.$emit).toHaveBeenCalledWith('close.form');
      });
    });

    describe('handleTestCaseUpdated', () => {
      it('assigns value of provided testCase param to `testCase` prop', () => {
        const updatedTestCase = {
          ...mockTestCase,
          title: 'Foo',
        };

        wrapper.vm.handleTestCaseUpdated(updatedTestCase);

        expect(wrapper.vm.testCase).toBe(updatedTestCase);
      });
    });
  });

  describe('template', () => {
    it('renders gl-loading-icon when testCaseLoading prop is true', async () => {
      wrapper.setData({
        testCaseLoading: true,
      });

      await wrapper.vm.$nextTick();

      expect(wrapper.find(GlLoadingIcon).exists()).toBe(true);
    });

    it('renders issuable-show when `testCaseLoading` prop is false', () => {
      const { statusBadgeClass, statusIcon, editTestCaseFormVisible } = wrapper.vm;
      const { canEditTestCase, descriptionPreviewPath, descriptionHelpPath } = mockProvide;
      const issuableShowEl = wrapper.find(IssuableShow);

      expect(issuableShowEl.exists()).toBe(true);
      expect(issuableShowEl.props()).toMatchObject({
        statusBadgeClass,
        statusIcon,
        descriptionPreviewPath,
        descriptionHelpPath,
        enableAutocomplete: true,
        issuable: mockTestCase,
        enableEdit: canEditTestCase,
        editFormVisible: editTestCaseFormVisible,
      });
    });

    it('renders status-badge slot contents', () => {
      expect(wrapper.find('[data-testid="status"]').text()).toContain('Open');
    });

    it('renders header-actions slot contents', () => {
      expect(wrapper.find('[data-testid="actions-dropdown"]').exists()).toBe(true);
      expect(wrapper.find('[data-testid="archive-test-case"]').exists()).toBe(true);
      expect(wrapper.find('[data-testid="new-test-case"]').exists()).toBe(true);
    });

    it('renders edit-form-actions slot contents', async () => {
      wrapper.setData({
        editTestCaseFormVisible: true,
      });

      await wrapper.vm.$nextTick();

      expect(wrapper.find('[data-testid="save-test-case"]').exists()).toBe(true);
      expect(wrapper.find('[data-testid="cancel-test-case-edit"]').exists()).toBe(true);
    });

    it('renders test-case-sidebar', async () => {
      expect(wrapper.find(TestCaseSidebar).exists()).toBe(true);
    });
  });
});
