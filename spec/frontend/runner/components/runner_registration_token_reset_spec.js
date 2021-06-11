import { GlButton } from '@gitlab/ui';
import { createLocalVue, shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createFlash, { FLASH_TYPES } from '~/flash';
import RunnerRegistrationTokenReset from '~/runner/components/runner_registration_token_reset.vue';
import runnersRegistrationTokenReset from '~/runner/graphql/runners_registration_token_reset.mutation.graphql';

jest.mock('~/flash');

const localVue = createLocalVue();
localVue.use(VueApollo);

const mockNewToken = 'NEW_TOKEN';

describe('RunnerRegistrationTokenReset', () => {
  let wrapper;
  let runnersRegistrationTokenResetHandler;

  const findButton = () => wrapper.findComponent(GlButton);

  const createComponent = () => {
    wrapper = shallowMount(RunnerRegistrationTokenReset, {
      localVue,
      apolloProvider: createMockApollo([
        [runnersRegistrationTokenReset, runnersRegistrationTokenResetHandler],
      ]),
    });
  };

  beforeEach(() => {
    runnersRegistrationTokenResetHandler = jest.fn().mockResolvedValue({
      data: {
        runnersRegistrationTokenReset: {
          token: mockNewToken,
          errors: [],
        },
      },
    });

    createComponent();

    jest.spyOn(window, 'confirm');
  });

  afterEach(() => {
    wrapper.destroy();
  });

  it('Displays reset button', () => {
    expect(findButton().exists()).toBe(true);
  });

  describe('On click and confirmation', () => {
    beforeEach(async () => {
      window.confirm.mockReturnValueOnce(true);
      await findButton().vm.$emit('click');
    });

    it('resets token', () => {
      expect(runnersRegistrationTokenResetHandler).toHaveBeenCalledTimes(1);
      expect(runnersRegistrationTokenResetHandler).toHaveBeenCalledWith({ input: {} });
    });

    it('emits result', () => {
      expect(wrapper.emitted('tokenReset')).toHaveLength(1);
      expect(wrapper.emitted('tokenReset')[0]).toEqual([mockNewToken]);
    });

    it('does not show a loading state', () => {
      expect(findButton().props('loading')).toBe(false);
    });

    it('shows confirmation', () => {
      expect(createFlash).toHaveBeenLastCalledWith({
        message: expect.stringContaining('registration token has been generated'),
        type: FLASH_TYPES.SUCCESS,
      });
    });
  });

  describe('On click without confirmation', () => {
    beforeEach(async () => {
      window.confirm.mockReturnValueOnce(false);
      await findButton().vm.$emit('click');
    });

    it('does not reset token', () => {
      expect(runnersRegistrationTokenResetHandler).not.toHaveBeenCalled();
    });

    it('does not emit any result', () => {
      expect(wrapper.emitted('tokenReset')).toBeUndefined();
    });

    it('does not show a loading state', () => {
      expect(findButton().props('loading')).toBe(false);
    });

    it('does not shows confirmation', () => {
      expect(createFlash).not.toHaveBeenCalled();
    });
  });

  describe('On error', () => {
    it('On network error, error message is shown', async () => {
      runnersRegistrationTokenResetHandler.mockRejectedValueOnce(new Error('Something went wrong'));

      window.confirm.mockReturnValueOnce(true);
      await findButton().vm.$emit('click');
      await waitForPromises();

      expect(createFlash).toHaveBeenLastCalledWith({
        message: 'Network error: Something went wrong',
      });
    });

    it('On validation error, error message is shown', async () => {
      runnersRegistrationTokenResetHandler.mockResolvedValue({
        data: {
          runnersRegistrationTokenReset: {
            token: null,
            errors: ['Token reset failed'],
          },
        },
      });

      window.confirm.mockReturnValueOnce(true);
      await findButton().vm.$emit('click');
      await waitForPromises();

      expect(createFlash).toHaveBeenLastCalledWith({
        message: 'Token reset failed',
      });
    });
  });

  describe('Immediately after click', () => {
    it('shows loading state', async () => {
      window.confirm.mockReturnValue(true);
      await findButton().vm.$emit('click');

      expect(findButton().props('loading')).toBe(true);
    });
  });
});
