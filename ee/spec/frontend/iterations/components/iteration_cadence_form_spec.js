import { GlFormCheckbox, GlFormGroup } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import IterationCadenceForm from 'ee/iterations/components/iteration_cadence_form.vue';
import createCadence from 'ee/iterations/queries/cadence_create.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { TEST_HOST } from 'helpers/test_constants';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

const push = jest.fn();
const $router = {
  currentRoute: {
    params: {},
  },
  push,
};

function createMockApolloProvider(requestHandlers) {
  Vue.use(VueApollo);

  return createMockApollo(requestHandlers);
}

describe('Iteration cadence form', () => {
  let wrapper;
  const groupPath = 'gitlab-org';
  const id = 72;
  const iterationCadence = {
    id: `gid://gitlab/Iterations::Cadence/${id}`,
    title: 'An iteration',
    description: 'The words',
    startDate: '2020-06-28',
    dueDate: '2020-07-05',
  };

  const createMutationSuccess = {
    data: { iterationCadenceCreate: { iterationCadence, errors: [] } },
  };
  const createMutationFailure = {
    data: {
      iterationCadenceCreate: { iterationCadence, errors: ['alas, your data is unchanged'] },
    },
  };

  function createComponent({ query = createCadence, resolverMock } = {}) {
    const apolloProvider = createMockApolloProvider([[query, resolverMock]]);
    wrapper = extendedWrapper(
      mount(IterationCadenceForm, {
        apolloProvider,
        mocks: {
          $router,
        },
        provide: {
          groupPath,
          cadencesListPath: TEST_HOST,
        },
      }),
    );
  }

  afterEach(() => {
    wrapper.destroy();
  });

  const findTitleGroup = () => wrapper.findAllComponents(GlFormGroup).at(0);
  const findAutomatedSchedulingGroup = () => wrapper.findAllComponents(GlFormGroup).at(1);
  const findStartDateGroup = () => wrapper.findAllComponents(GlFormGroup).at(2);
  const findDurationGroup = () => wrapper.findAllComponents(GlFormGroup).at(3);
  const findFutureIterationsGroup = () => wrapper.findAllComponents(GlFormGroup).at(4);

  const findTitle = () => wrapper.find('#cadence-title');
  const findStartDate = () => wrapper.find('#cadence-start-date');
  const findFutureIterations = () => wrapper.find('#cadence-schedule-future-iterations');
  const findDuration = () => wrapper.find('#cadence-duration');

  const findAllFields = () => [
    findTitle(),
    findStartDate(),
    findFutureIterations(),
    findDuration(),
  ];

  const findSaveButton = () => wrapper.findByTestId('save-cadence');
  const findCancelButton = () => wrapper.findByTestId('cancel-create-cadence');
  const clickSave = () => findSaveButton().vm.$emit('click');
  const clickCancel = () => findCancelButton().vm.$emit('click');

  describe('Create cadence', () => {
    let resolverMock;

    beforeEach(() => {
      resolverMock = jest.fn().mockResolvedValue(createMutationSuccess);
      createComponent({ resolverMock });
    });

    it('cancel button links to list page', () => {
      clickCancel();

      expect(push).toHaveBeenCalledWith({ name: 'index' });
    });

    describe('save', () => {
      it('triggers mutation with form data', () => {
        const title = 'Iteration 5';
        const startDate = '2020-05-05';
        const durationInWeeks = 2;
        const iterationsInAdvance = 6;

        findTitle().vm.$emit('input', title);
        findStartDate().vm.$emit('input', startDate);
        findDuration().vm.$emit('input', durationInWeeks);
        findFutureIterations().vm.$emit('input', iterationsInAdvance);

        clickSave();

        expect(resolverMock).toHaveBeenCalledWith({
          input: {
            groupPath,
            title,
            automatic: true,
            startDate,
            durationInWeeks,
            iterationsInAdvance,
            active: true,
          },
        });
      });

      it('redirects to Iteration page on success', async () => {
        const title = 'Iteration 5';
        const startDate = '2020-05-05';
        const durationInWeeks = 2;
        const iterationsInAdvance = 6;

        findTitle().vm.$emit('input', title);
        findStartDate().vm.$emit('input', startDate);
        findDuration().vm.$emit('input', durationInWeeks);
        findFutureIterations().vm.$emit('input', iterationsInAdvance);

        clickSave();

        await waitForPromises();

        expect(push).toHaveBeenCalledWith({ name: 'index' });
      });

      it('does not submit if required fields missing', () => {
        clickSave();

        expect(resolverMock).not.toHaveBeenCalled();
        expect(findTitleGroup().text()).toContain('This field is required');
        expect(findStartDateGroup().text()).toContain('This field is required');
        expect(findDurationGroup().text()).toContain('This field is required');
        expect(findFutureIterationsGroup().text()).toContain('This field is required');
      });

      it('loading=false on error', async () => {
        resolverMock = jest.fn().mockResolvedValue(createMutationFailure);
        createComponent({ resolverMock });

        clickSave();

        await waitForPromises();

        expect(findSaveButton().props('loading')).toBe(false);
      });
    });

    describe('automated scheduling disabled', () => {
      beforeEach(() => {
        findAutomatedSchedulingGroup().find(GlFormCheckbox).vm.$emit('input', false);
      });

      it('disables future iterations', () => {
        expect(findFutureIterations().attributes('disabled')).toBe('disabled');
      });

      it('does not require future iterations ', () => {
        const title = 'Iteration 5';
        const startDate = '2020-05-05';
        const durationInWeeks = 2;

        findTitle().vm.$emit('input', title);
        findStartDate().vm.$emit('input', startDate);
        findDuration().vm.$emit('input', durationInWeeks);

        clickSave();

        expect(resolverMock).toHaveBeenCalledWith({
          input: {
            groupPath,
            title,
            automatic: false,
            startDate,
            durationInWeeks,
            active: true,
          },
        });
      });
    });
  });

  describe('Edit cadence', () => {
    beforeEach(() => {
      $router.currentRoute.params.cadenceId = id;
    });

    afterEach(() => {
      delete $router.currentRoute.params.cadenceId;
    });

    it('shows correct title and button text', () => {
      const resolverMock = jest.fn().mockResolvedValue(createMutationSuccess);
      createComponent({ resolverMock });

      expect(wrapper.text()).toContain(wrapper.vm.i18n.edit.title);
      expect(wrapper.text()).toContain(wrapper.vm.i18n.edit.save);
    });

    it('disables fields while loading', async () => {
      const resolverMock = jest.fn().mockResolvedValue(createMutationSuccess);
      createComponent({ resolverMock });

      await nextTick();

      findAllFields().forEach(({ element }) => {
        expect(element).toBeDisabled();
      });

      await waitForPromises();

      findAllFields().forEach(({ element }) => {
        expect(element).not.toBeDisabled();
      });
    });

    it('fills fields with existing cadence info after loading', async () => {
      const resolverMock = jest.fn().mockResolvedValue(createMutationSuccess);
      createComponent({ resolverMock });

      await waitForPromises();

      findAllFields().forEach(({ element }) => {
        expect(element).not.toBeDisabled();
      });
    });
  });
});
