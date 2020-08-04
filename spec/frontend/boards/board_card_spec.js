/* global List */
/* global ListAssignee */
/* global ListLabel */

import { shallowMount } from '@vue/test-utils';

import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import waitForPromises from 'helpers/wait_for_promises';

import eventHub from '~/boards/eventhub';
import sidebarEventHub from '~/sidebar/event_hub';
import '~/boards/models/label';
import '~/boards/models/assignee';
import '~/boards/models/list';
import store from '~/boards/stores';
import boardsStore from '~/boards/stores/boards_store';
import boardCard from '~/boards/components/board_card.vue';
import issueCardInner from '~/boards/components/issue_card_inner.vue';
import userAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import { listObj, boardsMockInterceptor, setMockEndpoints } from './mock_data';
import { sidebarTypes } from '~/boards/constants';

describe('Board card', () => {
  let wrapper;
  let mock;
  let list;

  const findIssueCardInner = () => wrapper.find(issueCardInner);
  const findUserAvatarLink = () => wrapper.find(userAvatarLink);

  // this particular mount component needs to be used after the root beforeEach because it depends on list being initialized
  const mountComponent = propsData => {
    wrapper = shallowMount(boardCard, {
      stubs: {
        issueCardInner,
      },
      store,
      propsData: {
        list,
        issue: list.issues[0],
        issueLinkBase: '/',
        disabled: false,
        index: 0,
        rootPath: '/',
        ...propsData,
      },
      provide: {
        glFeatures: {
          boardsWithSwimlanes: true,
        },
      },
    });
  };

  const setupData = () => {
    list = new List(listObj);
    boardsStore.create();
    boardsStore.detail.issue = {};
    const label1 = new ListLabel({
      id: 3,
      title: 'testing 123',
      color: '#000cff',
      text_color: 'white',
      description: 'test',
    });
    return waitForPromises().then(() => {
      list.issues[0].labels.push(label1);
    });
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);
    mock.onAny().reply(boardsMockInterceptor);
    setMockEndpoints();
    return setupData();
  });

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
    list = null;
    mock.restore();
  });

  it('when details issue is empty does not show the element', () => {
    mountComponent();
    expect(wrapper.classes()).not.toContain('is-active');
  });

  it('when detailIssue is equal to card issue shows the element', () => {
    [boardsStore.detail.issue] = list.issues;
    mountComponent();

    expect(wrapper.classes()).toContain('is-active');
  });

  it('when multiSelect does not contain issue removes multi select class', () => {
    mountComponent();
    expect(wrapper.classes()).not.toContain('multi-select');
  });

  it('when multiSelect contain issue add multi select class', () => {
    boardsStore.multiSelect.list = [list.issues[0]];
    mountComponent();

    expect(wrapper.classes()).toContain('multi-select');
  });

  it('adds user-can-drag class if not disabled', () => {
    mountComponent();
    expect(wrapper.classes()).toContain('user-can-drag');
  });

  it('does not add user-can-drag class disabled', () => {
    mountComponent({ disabled: true });

    expect(wrapper.classes()).not.toContain('user-can-drag');
  });

  it('does not add disabled class', () => {
    mountComponent();
    expect(wrapper.classes()).not.toContain('is-disabled');
  });

  it('adds disabled class is disabled is true', () => {
    mountComponent({ disabled: true });

    expect(wrapper.classes()).toContain('is-disabled');
  });

  describe('mouse events', () => {
    it('sets showDetail to true on mousedown', () => {
      mountComponent();
      wrapper.trigger('mousedown');
      return wrapper.vm.$nextTick().then(() => {
        expect(wrapper.vm.showDetail).toBe(true);
      });
    });

    it('sets showDetail to false on mousemove', () => {
      mountComponent();
      wrapper.trigger('mousedown');
      return wrapper.vm
        .$nextTick()
        .then(() => {
          expect(wrapper.vm.showDetail).toBe(true);
          wrapper.trigger('mousemove');
          return wrapper.vm.$nextTick();
        })
        .then(() => {
          expect(wrapper.vm.showDetail).toBe(false);
        });
    });

    it('does not set detail issue if showDetail is false', () => {
      mountComponent();
      expect(boardsStore.detail.issue).toEqual({});
    });

    it('does not set detail issue if link is clicked', () => {
      mountComponent();
      findIssueCardInner()
        .find('a')
        .trigger('mouseup');

      expect(boardsStore.detail.issue).toEqual({});
    });

    it('does not set detail issue if img is clicked', () => {
      mountComponent({
        issue: {
          ...list.issues[0],
          assignees: [
            new ListAssignee({
              id: 1,
              name: 'testing 123',
              username: 'test',
              avatar: 'test_image',
            }),
          ],
        },
      });

      findUserAvatarLink().trigger('mouseup');

      expect(boardsStore.detail.issue).toEqual({});
    });

    it('does not set detail issue if showDetail is false after mouseup', () => {
      mountComponent();
      wrapper.trigger('mouseup');

      expect(boardsStore.detail.issue).toEqual({});
    });

    it('sets detail issue to card issue on mouse up', () => {
      jest.spyOn(eventHub, '$emit').mockImplementation(() => {});

      mountComponent();

      wrapper.trigger('mousedown');
      wrapper.trigger('mouseup');

      expect(eventHub.$emit).toHaveBeenCalledWith('newDetailIssue', wrapper.vm.issue, undefined);
      expect(boardsStore.detail.list).toEqual(wrapper.vm.list);
    });

    it('resets detail issue to empty if already set', () => {
      jest.spyOn(eventHub, '$emit').mockImplementation(() => {});
      const [issue] = list.issues;
      boardsStore.detail.issue = issue;
      mountComponent();

      wrapper.trigger('mousedown');
      wrapper.trigger('mouseup');

      expect(eventHub.$emit).toHaveBeenCalledWith('clearDetailIssue', undefined);
    });
  });

  describe('sidebarHub events', () => {
    it('closes all sidebars before showing an issue if no issues are opened', () => {
      jest.spyOn(sidebarEventHub, '$emit').mockImplementation(() => {});
      boardsStore.detail.issue = {};
      mountComponent();

      wrapper.trigger('mouseup');

      expect(sidebarEventHub.$emit).toHaveBeenCalledWith('sidebar.closeAll');
    });

    it('it does not closes all sidebars before showing an issue if an issue is opened', () => {
      jest.spyOn(sidebarEventHub, '$emit').mockImplementation(() => {});
      const [issue] = list.issues;
      boardsStore.detail.issue = issue;
      mountComponent();

      wrapper.trigger('mousedown');

      expect(sidebarEventHub.$emit).not.toHaveBeenCalledWith('sidebar.closeAll');
    });
  });

  describe('when boardsWithSwimlanes is on', () => {
    describe('when isShowingEpicsSwimlanes', () => {
      describe('when a board card is clicked', () => {
        beforeEach(() => {
          jest.spyOn(store, 'dispatch').mockImplementation();

          store.state.isShowingEpicsSwimlanes = true;
          store.state.activeId = 1;

          mountComponent();
        });

        it('calls setActiveId', () => {
          wrapper.trigger('mouseup');

          expect(store.dispatch).toHaveBeenCalledWith('setActiveId', {
            id: 1,
            sidebarType: sidebarTypes.issuable,
          });
        });

        it('sets card to active', async () => {
          wrapper.trigger('mouseup');

          await waitForPromises();

          expect(wrapper.find('[data-qa-selector="board_card"]').classes()).toContain('is-active');
        });
      });
    });
  });
});
