import { merge } from 'lodash';
import { shallowMount, mount } from '@vue/test-utils';
import { GlAlert, GlLink } from '@gitlab/ui';
import CiLint from '~/pipeline_editor/components/lint/ci_lint.vue';
import { CI_CONFIG_STATUS_INVALID } from '~/pipeline_editor/constants';
import { mockCiConfigQueryResponse, mockLintHelpPagePath } from '../../mock_data';

const mockCiConfig = mockCiConfigQueryResponse.data.ciConfig;

const mergeCiCongig = config => {
  return merge(mockCiConfig, config);
};

describe('~/pipeline_editor/components/lint/ci_lint.vue', () => {
  let wrapper;

  const createComponent = (props = {}, mountFn = shallowMount) => {
    wrapper = mountFn(CiLint, {
      provide: {
        lintHelpPagePath: mockLintHelpPagePath,
      },
      propsData: {
        ciConfig: mockCiConfig,
        ...props,
      },
    });
  };

  const findAllByTestId = selector => wrapper.findAll(`[data-testid="ci-lint-${selector}"]`);
  const findAlert = () => wrapper.find(GlAlert);
  const findLintParameters = () => findAllByTestId('parameter');
  const findLintParameterAt = i => findLintParameters().at(i);

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  describe('Valid Results', () => {
    beforeEach(() => {
      createComponent({}, mount);
    });

    it('displays valid results', () => {
      expect(findAlert().text()).toMatch('Status: syntax is correct.');
    });

    it('displays link to the right help page', () => {
      expect(
        findAlert()
          .find(GlLink)
          .attributes('href'),
      ).toBe(mockLintHelpPagePath);
    });

    it('displays jobs', () => {
      expect(findLintParameters()).toHaveLength(3);
      expect(findLintParameterAt(0).text()).toBe('Test Job - job_test_1');
      expect(findLintParameterAt(1).text()).toBe('Test Job - job_test_2');
      expect(findLintParameterAt(2).text()).toBe('Build Job - job_build');
    });

    it('displays invalid results', () => {
      createComponent(
        {
          ciConfig: mergeCiCongig({
            status: CI_CONFIG_STATUS_INVALID,
          }),
        },
        mount,
      );

      expect(findAlert().text()).toMatch('Status: syntax is incorrect.');
    });
  });
});
