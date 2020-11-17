import { shallowMount } from '@vue/test-utils';

import IssuableShowRoot from '~/issuable_show/components/issuable_show_root.vue';

import IssuableHeader from '~/issuable_show/components/issuable_header.vue';
import IssuableBody from '~/issuable_show/components/issuable_body.vue';
import IssuableSidebar from '~/issuable_sidebar/components/issuable_sidebar_root.vue';

import { mockIssuableShowProps, mockIssuable } from '../mock_data';

const createComponent = (propsData = mockIssuableShowProps) =>
  shallowMount(IssuableShowRoot, {
    propsData,
    stubs: {
      IssuableHeader,
      IssuableBody,
      IssuableSidebar,
    },
    slots: {
      'status-badge': 'Open',
      'header-actions': `
        <button class="js-close">Close issuable</button>
        <a class="js-new" href="/gitlab-org/gitlab-shell/-/issues/new">New issuable</a>
      `,
      'edit-form-actions': `
        <button class="js-save">Save changes</button>
        <button class="js-cancel">Cancel</button>
      `,
      'right-sidebar-items': `
        <div class="js-todo">
          To Do <button class="js-add-todo">Add a To Do</button>
        </div>
      `,
    },
  });

describe('IssuableShowRoot', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = createComponent();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('template', () => {
    const {
      statusBadgeClass,
      statusIcon,
      enableEdit,
      enableAutocomplete,
      editFormVisible,
      descriptionPreviewPath,
      descriptionHelpPath,
    } = mockIssuableShowProps;
    const { blocked, confidential, createdAt, author } = mockIssuable;

    it('renders component container element with class `issuable-show-container`', () => {
      expect(wrapper.classes()).toContain('issuable-show-container');
    });

    it('renders issuable-header component', () => {
      const issuableHeader = wrapper.find(IssuableHeader);

      expect(issuableHeader.exists()).toBe(true);
      expect(issuableHeader.props()).toMatchObject({
        statusBadgeClass,
        statusIcon,
        blocked,
        confidential,
        createdAt,
        author,
      });
      expect(issuableHeader.find('.issuable-status-box').text()).toContain('Open');
      expect(issuableHeader.find('.detail-page-header-actions button.js-close').exists()).toBe(
        true,
      );
      expect(issuableHeader.find('.detail-page-header-actions a.js-new').exists()).toBe(true);
    });

    it('renders issuable-body component', () => {
      const issuableBody = wrapper.find(IssuableBody);

      expect(issuableBody.exists()).toBe(true);
      expect(issuableBody.props()).toMatchObject({
        issuable: mockIssuable,
        statusBadgeClass,
        statusIcon,
        enableEdit,
        enableAutocomplete,
        editFormVisible,
        descriptionPreviewPath,
        descriptionHelpPath,
      });
    });

    it('renders issuable-sidebar component', () => {
      const issuableSidebar = wrapper.find(IssuableSidebar);

      expect(issuableSidebar.exists()).toBe(true);
    });

    describe('events', () => {
      it('component emits `edit-issuable` event bubbled via issuable-body', () => {
        const issuableBody = wrapper.find(IssuableBody);

        issuableBody.vm.$emit('edit-issuable');

        expect(wrapper.emitted('edit-issuable')).toBeTruthy();
      });

      it('component emits `sidebar-toggle` event bubbled via issuable-sidebar', () => {
        const issuableSidebar = wrapper.find(IssuableSidebar);

        issuableSidebar.vm.$emit('sidebar-toggle', true);

        expect(wrapper.emitted('sidebar-toggle')).toBeTruthy();
      });
    });
  });
});
