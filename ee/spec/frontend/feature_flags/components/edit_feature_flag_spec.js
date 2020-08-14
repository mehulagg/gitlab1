import Vuex from 'vuex';
import { createLocalVue, shallowMount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import { GlToggle, GlAlert } from '@gitlab/ui';
import { LEGACY_FLAG, NEW_VERSION_FLAG, NEW_FLAG_ALERT } from 'ee/feature_flags/constants';
import Form from 'ee/feature_flags/components/form.vue';
import editModule from 'ee/feature_flags/store/modules/edit';
import EditFeatureFlag from 'ee/feature_flags/components/edit_feature_flag.vue';
import { TEST_HOST } from 'spec/test_constants';
import axios from '~/lib/utils/axios_utils';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('Edit feature flag form', () => {
  let wrapper;
  let mock;

  const store = new Vuex.Store({
    modules: {
      edit: editModule,
    },
  });

  const factory = (opts = {}) => {
    if (wrapper) {
      wrapper.destroy();
      wrapper = null;
    }
    wrapper = shallowMount(EditFeatureFlag, {
      localVue,
      propsData: {
        endpoint: `${TEST_HOST}/feature_flags.json`,
        path: '/feature_flags',
        environmentsEndpoint: 'environments.json',
        projectId: '8',
        featureFlagIssuesEndpoint: `${TEST_HOST}/feature_flags/5/issues`,
      },
      store,
      provide: {
        glFeatures: {
          featureFlagsNewVersion: true,
        },
      },
      ...opts,
    });
  };

  beforeEach(done => {
    mock = new MockAdapter(axios);

    mock.onGet(`${TEST_HOST}/feature_flags.json`).replyOnce(200, {
      id: 21,
      iid: 5,
      active: true,
      created_at: '2019-01-17T17:27:39.778Z',
      updated_at: '2019-01-17T17:27:39.778Z',
      name: 'feature_flag',
      description: '',
      version: LEGACY_FLAG,
      edit_path: '/h5bp/html5-boilerplate/-/feature_flags/21/edit',
      destroy_path: '/h5bp/html5-boilerplate/-/feature_flags/21',
      scopes: [
        {
          id: 21,
          active: false,
          environment_scope: '*',
          created_at: '2019-01-17T17:27:39.778Z',
          updated_at: '2019-01-17T17:27:39.778Z',
        },
      ],
    });

    factory();

    setImmediate(() => done());
  });

  afterEach(() => {
    wrapper.destroy();
    mock.restore();
  });

  it('should display the iid', () => {
    expect(wrapper.find('h3').text()).toContain('^5');
  });

  it('should render the toggle', () => {
    expect(wrapper.find(GlToggle).exists()).toBe(true);
  });

  it('should set the value of the toggle to whether or not the flag is active', () => {
    expect(wrapper.find(GlToggle).props('value')).toBe(true);
  });

  it('should not alert users that feature flags are changing soon', () => {
    expect(wrapper.find(GlAlert).text()).not.toBe(NEW_FLAG_ALERT);
  });

  describe('with error', () => {
    it('should render the error', () => {
      store.dispatch('edit/receiveUpdateFeatureFlagError', { message: ['The name is required'] });

      return wrapper.vm.$nextTick(() => {
        expect(wrapper.find('.alert-danger').exists()).toEqual(true);
        expect(wrapper.find('.alert-danger').text()).toContain('The name is required');
      });
    });
  });

  describe('without error', () => {
    it('renders form title', () => {
      expect(wrapper.text()).toContain('^5 feature_flag');
    });

    it('should render feature flag form', () => {
      expect(wrapper.find(Form).exists()).toEqual(true);
    });

    it('should set the version of the form from the feature flag', () => {
      expect(wrapper.find(Form).props('version')).toBe(LEGACY_FLAG);

      mock.resetHandlers();

      mock.onGet(`${TEST_HOST}/feature_flags.json`).replyOnce(200, {
        id: 21,
        iid: 5,
        active: true,
        created_at: '2019-01-17T17:27:39.778Z',
        updated_at: '2019-01-17T17:27:39.778Z',
        name: 'feature_flag',
        description: '',
        version: NEW_VERSION_FLAG,
        edit_path: '/h5bp/html5-boilerplate/-/feature_flags/21/edit',
        destroy_path: '/h5bp/html5-boilerplate/-/feature_flags/21',
        strategies: [],
      });

      factory();

      return axios.waitForAll().then(() => {
        expect(wrapper.find(Form).props('version')).toBe(NEW_VERSION_FLAG);
      });
    });

    it('renders the related issues widget', () => {
      const expected = `${TEST_HOST}/feature_flags/5/issues`;

      expect(wrapper.find(Form).props('featureFlagIssuesEndpoint')).toBe(expected);
    });
  });

  describe('without new version flags', () => {
    beforeEach(() => factory({ provide: { glFeatures: { featureFlagsNewVersion: false } } }));

    it('should alert users that feature flags are changing soon', () => {
      expect(wrapper.find(GlAlert).text()).toBe(NEW_FLAG_ALERT);
    });

    it('the new feature flags alert should be dismissable', () => {
      expect(wrapper.find(GlAlert).props('dismissible')).toBe(true);
    });
  });
});
