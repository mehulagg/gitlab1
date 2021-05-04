import { GlSkeletonLoader, GlAlert } from '@gitlab/ui';
import { createLocalVue, shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getJobsQuery from '~/jobs/components/table/graphql/queries/get_jobs.query.graphql';
import JobsTable from '~/jobs/components/table/jobs_table.vue';
import JobsTableApp from '~/jobs/components/table/jobs_table_app.vue';
import JobsTableTabs from '~/jobs/components/table/jobs_table_tabs.vue';
import { mockJobsQueryResponse } from '../../mock_data';

const projectPath = 'gitlab-org/gitlab';
const localVue = createLocalVue();
localVue.use(VueApollo);

describe('Job table app', () => {
  let wrapper;

  const successHandler = jest.fn().mockResolvedValue(mockJobsQueryResponse);
  const failedHandler = jest.fn().mockRejectedValue(new Error('GraphQL error'));

  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findTable = () => wrapper.findComponent(JobsTable);
  const findTabs = () => wrapper.findComponent(JobsTableTabs);
  const findAlert = () => wrapper.findComponent(GlAlert);

  const createMockApolloProvider = (handler) => {
    const requestHandlers = [[getJobsQuery, handler]];

    return createMockApollo(requestHandlers);
  };

  const createComponent = (handler = successHandler) => {
    wrapper = shallowMount(JobsTableApp, {
      provide: {
        projectPath,
      },
      localVue,
      apolloProvider: createMockApolloProvider(handler),
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('loading state', () => {
    it('should display skeleton loader when loading', () => {
      createComponent();

      expect(findSkeletonLoader().exists()).toBe(true);
      expect(findTable().exists()).toBe(false);
    });
  });

  describe('loaded state', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('should display the jobs table with data', () => {
      expect(findTable().exists()).toBe(true);
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    it('should retfech jobs query on fetchJobsByStatus event', async () => {
      jest.spyOn(wrapper.vm.$apollo.queries.jobs, 'refetch').mockImplementation(jest.fn());

      expect(wrapper.vm.$apollo.queries.jobs.refetch).toHaveBeenCalledTimes(0);

      await findTabs().vm.$emit('fetchJobsByStatus');

      expect(wrapper.vm.$apollo.queries.jobs.refetch).toHaveBeenCalledTimes(1);
    });
  });

  describe('error state', () => {
    it('should show an alert if there is an error fetching the data', async () => {
      createComponent(failedHandler);

      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
    });
  });
});
