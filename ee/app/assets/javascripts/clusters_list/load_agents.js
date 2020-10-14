import Agents from './components/agents.vue';
import createDefaultClient from '~/lib/graphql';
import getAgentsQuery from './graphql/queries/get_agents.query.graphql';

export default (Vue, VueApollo) => {
  const el = document.querySelector('#js-cluster-agents-list');

  if (!el) {
    return null;
  }

  const defaultClient = createDefaultClient();

  defaultClient.cache.writeQuery({
    query: getAgentsQuery,
    /* eslint-disable @gitlab/require-i18n-strings */
    data: {
      project: {
        __typename: 'Project',
        clusterAgents: {
          __typename: 'ClusterAgents',
          nodes: [],
          pageInfo: {
            __typename: 'ClusterAgentsPagination',
            startCursor: String,
            endCursor: String,
            hasNextPage: Boolean,
            hasPreviousPage: Boolean,
          },
        },

        repository: {
          __typename: 'Repository',
          tree: {
            __typename: 'Tree',
            trees: {
              __typename: 'Trees',
              nodes: [],
            },
          },
        },
      },
    },
  });

  const { emptyStateImage, defaultBranchName, projectPath } = el.dataset;

  return new Vue({
    el,
    apolloProvider: new VueApollo({ defaultClient }),
    render(createElement) {
      return createElement(Agents, {
        props: {
          emptyStateImage,
          defaultBranchName,
          projectPath,
        },
      });
    },
  });
};
