import Vue from 'vue';
import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import featureFlagsComponent from 'ee/feature_flags/components/feature_flags.vue';
import { createStore } from 'ee/feature_flags/store';
import { mountComponentWithStore } from 'spec/helpers/vue_mount_component_helper';
import { featureFlag } from './mock_data';

describe('Feature Flags', () => {
  const mockData = {
    endpoint: 'feature_flags.json',
    csrfToken: 'testToken',
    errorStateSvgPath: '/assets/illustrations/feature_flag.svg',
    featureFlagsHelpPagePath: '/help/feature-flags',
  };

  let store;
  let FeatureFlagsComponent;
  let component;
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);

    FeatureFlagsComponent = Vue.extend(featureFlagsComponent);
  });

  afterEach(() => {
    component.$destroy();
    mock.restore();
  });

  describe('successful request', () => {
    describe('with paginated feature flags', () => {
      beforeEach(done => {
        mock.onGet(mockData.endpoint).reply(
          200,
          {
            feature_flags: [featureFlag],
            count: {
              all: 37,
              enabled: 5,
              disabled: 32,
            },
          },
          {
            'X-nExt-pAge': '2',
            'x-page': '1',
            'X-Per-Page': '1',
            'X-Prev-Page': '',
            'X-TOTAL': '37',
            'X-Total-Pages': '2',
          },
        );

        store = createStore();

        component = mountComponentWithStore(FeatureFlagsComponent, {
          store,
          props: mockData,
        });

        setTimeout(() => {
          done();
        }, 0);
      });

      it('should render a table with feature flags', () => {
        expect(component.$el.querySelectorAll('.js-feature-flag-table')).not.toBeNull();
        expect(component.$el.querySelector('.feature-flag-name').textContent.trim()).toEqual(
          featureFlag.name,
        );

        expect(component.$el.querySelector('.feature-flag-description').textContent.trim()).toEqual(
          featureFlag.description,
        );
      });

      describe('pagination', () => {
        it('should render pagination', () => {
          expect(component.$el.querySelectorAll('.gl-pagination li').length).toEqual(5);
        });

        it('should make an API request when page is clicked', done => {
          spyOn(component, 'updateFeatureFlagOptions');
          setTimeout(() => {
            component.$el.querySelector('.gl-pagination li:nth-child(5) a').click();

            expect(component.updateFeatureFlagOptions).toHaveBeenCalledWith({
              scope: 'all',
              page: '2',
            });
            done();
          }, 0);
        });

        it('should make an API request when using tabs', done => {
          setTimeout(() => {
            spyOn(component, 'updateFeatureFlagOptions');
            component.$el.querySelector('.js-featureflags-tab-enabled').click();

            expect(component.updateFeatureFlagOptions).toHaveBeenCalledWith({
              scope: 'enabled',
              page: '1',
            });
            done();
          }, 0);
        });
      });
    });
  });

  describe('unsuccessful request', () => {
    beforeEach(done => {
      mock.onGet(mockData.endpoint).reply(500, {});

      store = createStore();
      component = mountComponentWithStore(FeatureFlagsComponent, {
        store,
        props: mockData,
      });

      setTimeout(() => {
        done();
      }, 0);
    });

    it('should render error state', () => {
      expect(component.$el.querySelector('.empty-state').textContent.trim()).toContain(
        'There was an error fetching the feature flags. Try again in a few moments or contact your support team.',
      );
    });
  });
});
