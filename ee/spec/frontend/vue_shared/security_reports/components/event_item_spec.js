import { GlDeprecatedButton } from '@gitlab/ui';
import Component from 'ee/vue_shared/security_reports/components/event_item.vue';
import { shallowMount, mount } from '@vue/test-utils';

describe('Event Item', () => {
  let wrapper;

  const mountComponent = (options, mountFn = shallowMount) => {
    wrapper = mountFn(Component, options);
  };

  describe('initial state', () => {
    const propsData = {
      author: {
        name: 'Tanuki',
        username: 'gitlab',
      },
    };

    afterEach(() => {
      wrapper.destroy();
    });

    beforeEach(() => {
      mountComponent({ propsData });
    });

    it('uses the author name', () => {
      expect(wrapper.find('.js-author').text()).toContain(propsData.author.name);
    });

    it('uses the author username', () => {
      expect(wrapper.find('.js-author').text()).toContain(`@${propsData.author.username}`);
    });

    it('uses the fallback icon', () => {
      expect(wrapper.props().iconName).toBe('plus');
    });

    it('uses the fallback icon class', () => {
      expect(wrapper.props().iconClass).toBe('ci-status-icon-success');
    });

    it('renders the action buttons tontainer', () => {
      expect(wrapper.find('.action-buttons')).toExist();
    });
  });
  describe('with action buttons', () => {
    const propsData = {
      author: {
        name: 'Tanuki',
        username: 'gitlab',
      },
      actionButtons: [
        {
          iconName: 'pencil',
          onClick: jest.fn(),
          title: 'Foo Action',
        },
        {
          iconName: 'remove',
          onClick: jest.fn(),
          title: 'Bar Action',
        },
      ],
    };

    afterEach(() => {
      wrapper.destroy();
    });

    beforeEach(() => {
      mountComponent({ propsData }, mount);
    });

    it('renders the action buttons container', () => {
      expect(wrapper.find('.action-buttons')).toExist();
    });

    it('renders the action buttons', () => {
      expect(wrapper.findAll(GlDeprecatedButton).length).toBe(2);
      expect(wrapper).toMatchSnapshot();
    });

    it('emits the button events when clicked', () => {
      const buttons = wrapper.findAll(GlDeprecatedButton);
      buttons.at(0).trigger('click');
      return wrapper.vm
        .$nextTick()
        .then(() => {
          buttons.at(1).trigger('click');
          return wrapper.vm.$nextTick();
        })
        .then(() => {
          expect(propsData.actionButtons[0].onClick).toHaveBeenCalledTimes(1);
          expect(propsData.actionButtons[1].onClick).toHaveBeenCalledTimes(1);
        });
    });
  });
});
