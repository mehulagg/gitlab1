import { createLocalVue, shallowMount } from '@vue/test-utils';
import VueRouter from 'vue-router';
import Toolbar from '~/design_management_new/components/toolbar/index.vue';
import DeleteButton from '~/design_management_new/components/delete_button.vue';
import { DESIGNS_ROUTE_NAME } from '~/design_management_new/router/constants';
import { GlDeprecatedButton } from '@gitlab/ui';

const localVue = createLocalVue();
localVue.use(VueRouter);
const router = new VueRouter();

const GlButtonGroupStub = {
  props: {
    to: {
      type: Object,
    },
  },
  render(createElement) {
    return createElement('div', {}, this.$slots.default);
  },
};

const GlButtonStub = {
  props: {
    to: {
      type: Object,
    },
  },
  render(createElement) {
    return createElement('a', {}, this.$slots.default);
  },
};

describe('Design management toolbar component', () => {
  let wrapper;

  function createComponent(isLoading = false, createDesign = true, props) {
    const updatedAt = new Date();
    updatedAt.setHours(updatedAt.getHours() - 1);

    wrapper = shallowMount(Toolbar, {
      localVue,
      router,
      propsData: {
        id: '1',
        isLatestVersion: true,
        isLoading,
        isDeleting: false,
        filename: 'test.jpg',
        updatedAt: updatedAt.toString(),
        updatedBy: {
          name: 'Test Name',
        },
        image: '/-/designs/306/7f747adcd4693afadbe968d7ba7d983349b9012d',
        ...props,
      },
      stubs: {
        'gl-button-group': GlButtonGroupStub,
        'gl-button': GlButtonStub,
      },
    });

    wrapper.setData({
      permissions: {
        createDesign,
      },
    });
  }

  afterEach(() => {
    wrapper.destroy();
  });

  it('renders design and updated data', () => {
    createComponent();

    return wrapper.vm.$nextTick().then(() => {
      expect(wrapper.element).toMatchSnapshot();
    });
  });

  it('links back to designs list', () => {
    createComponent();

    return wrapper.vm.$nextTick().then(() => {
      const link = wrapper.find('a');

      expect(link.props('to')).toEqual({
        name: DESIGNS_ROUTE_NAME,
        query: {
          version: undefined,
        },
      });
    });
  });

  it('renders delete button on latest designs version with logged in user', () => {
    createComponent();

    return wrapper.vm.$nextTick().then(() => {
      expect(wrapper.find(DeleteButton).exists()).toBe(true);
    });
  });

  it('does not render delete button on non-latest version', () => {
    createComponent(false, true, { isLatestVersion: false });

    return wrapper.vm.$nextTick().then(() => {
      expect(wrapper.find(DeleteButton).exists()).toBe(false);
    });
  });

  it('does not render delete button when user is not logged in', () => {
    createComponent(false, false);

    return wrapper.vm.$nextTick().then(() => {
      expect(wrapper.find(DeleteButton).exists()).toBe(false);
    });
  });

  it('emits `delete` event on deleteButton `deleteSelectedDesigns` event', () => {
    createComponent();

    return wrapper.vm.$nextTick().then(() => {
      wrapper.find(DeleteButton).vm.$emit('deleteSelectedDesigns');
      expect(wrapper.emitted().delete).toBeTruthy();
    });
  });

  it('renders download button with correct link', () => {
    expect(wrapper.find(GlDeprecatedButton).attributes('href')).toBe(
      '/-/designs/306/7f747adcd4693afadbe968d7ba7d983349b9012d',
    );
  });
});
