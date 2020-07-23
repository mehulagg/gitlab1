import Vuex from 'vuex';
import { shallowMount, createLocalVue } from '@vue/test-utils';
import { GlAlert, GlTable, GlEmptyState, GlIntersectionObserver } from '@gitlab/ui';
import FirstClassInstanceVulnerabilities from 'ee/security_dashboard/components/first_class_instance_security_dashboard_vulnerabilities.vue';
import VulnerabilityList from 'ee/security_dashboard/components/vulnerability_list.vue';
import { generateVulnerabilities } from './mock_data';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('First Class Instance Dashboard Vulnerabilities Component', () => {
  let wrapper;
  let store;

  const findIntersectionObserver = () => wrapper.find(GlIntersectionObserver);
  const findVulnerabilities = () => wrapper.find(VulnerabilityList);
  const findAlert = () => wrapper.find(GlAlert);

  const createWrapper = ({ stubs, loading = false, isUpdatingProjects, data } = {}) => {
    store = new Vuex.Store({
      modules: {
        projectSelector: {
          namespaced: true,
          actions: {
            fetchProjects() {},
            setProjectEndpoints() {},
          },
          getters: {
            isUpdatingProjects: jest.fn().mockReturnValue(isUpdatingProjects),
          },
          state: {
            projects: [],
          },
        },
      },
    });

    return shallowMount(FirstClassInstanceVulnerabilities, {
      localVue,
      store,
      stubs,
      mocks: {
        $apollo: {
          queries: { vulnerabilities: { loading } },
        },
        fetchNextPage: () => {},
      },
      data,
    });
  };

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  describe('when the query is loading', () => {
    beforeEach(() => {
      wrapper = createWrapper({
        loading: true,
      });
    });

    it('passes down isLoading correctly', () => {
      expect(findVulnerabilities().props()).toMatchObject({ isLoading: true });
    });
  });

  describe('when the query returned an error status', () => {
    beforeEach(() => {
      wrapper = createWrapper({
        stubs: {
          GlAlert,
        },
        data: () => ({
          isFirstResultLoading: false,
          errorLoadingVulnerabilities: true,
        }),
      });
    });

    it('displays the alert', () => {
      expect(findAlert().text()).toBe(
        'Error fetching the vulnerability list. Please check your network connection and try again.',
      );
    });

    it('should have an alert that is dismissable', () => {
      const alert = findAlert();
      alert.find('button').trigger('click');
      return wrapper.vm.$nextTick(() => {
        expect(alert.exists()).toBe(false);
      });
    });

    it('does not display the vulnerabilities', () => {
      expect(findVulnerabilities().exists()).toBe(false);
    });
  });

  describe('when the query is loaded and we have results', () => {
    const vulnerabilities = generateVulnerabilities();

    beforeEach(() => {
      wrapper = createWrapper({
        stubs: {
          VulnerabilityList,
          GlTable,
          GlEmptyState,
        },
        data: () => ({
          vulnerabilities,
          isFirstResultLoading: false,
        }),
      });
    });

    it('passes down properties correctly', () => {
      expect(findVulnerabilities().props()).toEqual({
        filters: {},
        isLoading: false,
        shouldShowIdentifier: false,
        securityScanners: {},
        shouldShowReportType: false,
        shouldShowSelection: true,
        shouldShowProjectNamespace: true,
        vulnerabilities,
      });
    });
  });

  describe('when there is more than a page of vulnerabilities', () => {
    const vulnerabilities = generateVulnerabilities();

    beforeEach(() => {
      wrapper = createWrapper({
        data: () => ({
          vulnerabilities,
          pageInfo: {
            hasNextPage: true,
          },
        }),
      });
    });

    it('should render the observer component', () => {
      expect(findIntersectionObserver().exists()).toBe(true);
    });
  });
});
