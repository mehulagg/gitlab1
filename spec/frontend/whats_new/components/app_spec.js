import { createLocalVue, mount } from '@vue/test-utils';
import Vuex from 'vuex';
import { GlDrawer } from '@gitlab/ui';
import App from '~/whats_new/components/app.vue';
import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import { TEST_HOST } from 'spec/test_constants';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('App', () => {
  let wrapper;
  let store;
  let actions;
  let state;
  let propsData = { storageKey: 'storage-key' };
  let axiosMock;

  const buildWrapper = () => {
    actions = {
      openDrawer: jest.fn(),
      closeDrawer: jest.fn(),
    };

    state = {
      open: true,
    };

    store = new Vuex.Store({
      actions,
      state,
    });

    wrapper = mount(App, {
      localVue,
      store,
      propsData,
    });
  };

  beforeEach(() => {
    axiosMock = new MockAdapter(axios);
    axiosMock.onGet('/-/whats_new').replyOnce(200, {
      data: [ {"title":"Whats New Drawer"} ]
    });
    buildWrapper();
  });

  afterEach(() => {
    wrapper.destroy();
    axiosMock.restore();
  });

  const getDrawer = () => wrapper.find(GlDrawer);

  it('contains a drawer', () => {
    expect(getDrawer().exists()).toBe(true);
  });

  it('dispatches openDrawer when mounted', () => {
    expect(actions.openDrawer).toHaveBeenCalled();
    expect(actions.openDrawer.mock.calls[0][1]).toBe('storage-key');
  });

  it('dispatches closeDrawer when clicking close', () => {
    getDrawer().vm.$emit('close');
    expect(actions.closeDrawer).toHaveBeenCalled();
  });

  it.each([true, false])('passes open property', async openState => {
    wrapper.vm.$store.state.open = openState;

    await wrapper.vm.$nextTick();

    expect(getDrawer().props('open')).toBe(openState);
  });

  it('renders features when provided as props', () => {
    expect(wrapper.find('h5').text()).toBe('Whats New Drawer');
  });
});
