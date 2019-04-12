import { shallowMount } from '@vue/test-utils';
import LicenseCardBody from 'ee/licenses/components/cards/license_card_body.vue';

describe('LicenseCardBody', () => {
  let wrapper;
  const defaultProps = {
    license: {
      userLimit: 10,
      historicalMax: 20,
      overage: 5,
      startsAt: '2013/10/10',
      expiresAt: '2015/10/10',
      licensee: {
        Name: 'Jon Dough',
        Email: 'email@address.tanuki',
        Company: 'TanukiVille',
      },
    },
    isRemoving: false,
    currentActiveUserCount: 10,
  };

  function createComponent(props) {
    const propsData = Object.assign({}, defaultProps, props);

    wrapper = shallowMount(LicenseCardBody, {
      propsData,
    });
  }

  beforeEach(() => {
    jest.spyOn(global.Date.prototype, 'toString').mockReturnValue('2017/10/10');
  });

  afterEach(() => {
    if (wrapper) wrapper.destroy();
    global.Date.prototype.toString.mockRestore();
  });

  it('renders a license card body', () => {
    createComponent();

    expect(wrapper.element).toMatchSnapshot();
  });

  it('renders a loading state if isRemoving', () => {
    createComponent({ isRemoving: true });

    expect(wrapper.element).toMatchSnapshot();
  });

  it('renders fallback licensee values', () => {
    createComponent({ licensee: {} });

    expect(wrapper.element).toMatchSnapshot();
  });
});
