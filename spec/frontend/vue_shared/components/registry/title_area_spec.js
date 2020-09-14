import { GlAvatar } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import component from '~/vue_shared/components/registry/title_area.vue';

describe('title area', () => {
  let wrapper;

  const findSubHeaderSlot = () => wrapper.find('[data-testid="sub-header"]');
  const findRightActionsSlot = () => wrapper.find('[data-testid="right-actions"]');
  const findMetadataSlot = name => wrapper.find(`[data-testid="${name}"]`);
  const findTitle = () => wrapper.find('[data-testid="title"]');
  const findAvatar = () => wrapper.find(GlAvatar);

  const mountComponent = ({ propsData = { title: 'foo' }, slots } = {}) => {
    wrapper = shallowMount(component, {
      propsData,
      slots: {
        'sub-header': '<div data-testid="sub-header" />',
        'right-actions': '<div data-testid="right-actions" />',
        ...slots,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  describe('title', () => {
    it('if slot is not present defaults to prop', () => {
      mountComponent();

      expect(findTitle().text()).toBe('foo');
    });
    it('if slot is present uses slot', () => {
      mountComponent({
        slots: {
          title: 'slot_title',
        },
      });
      expect(findTitle().text()).toBe('slot_title');
    });
  });

  describe('avatar', () => {
    it('is shown if avatar props exist', () => {
      mountComponent({ propsData: { title: 'foo', avatar: 'baz' } });

      expect(findAvatar().props('src')).toBe('baz');
    });

    it('is hidden if avatar props does not exist', () => {
      mountComponent();

      expect(findAvatar().exists()).toBe(false);
    });
  });

  describe.each`
    slotName           | finderFunction
    ${'sub-header'}    | ${findSubHeaderSlot}
    ${'right-actions'} | ${findRightActionsSlot}
  `('$slotName slot', ({ finderFunction, slotName }) => {
    it('exist when the slot is filled', () => {
      mountComponent();

      expect(finderFunction().exists()).toBe(true);
    });

    it('does not exist when the slot is empty', () => {
      mountComponent({ slots: { [slotName]: '' } });

      expect(finderFunction().exists()).toBe(false);
    });
  });

  describe.each`
    slotNames
    ${['metadata_foo']}
    ${['metadata_foo', 'metadata_bar']}
    ${['metadata_foo', 'metadata_bar', 'metadata_baz']}
  `('$slotNames metadata slots', ({ slotNames }) => {
    const slotMocks = slotNames.reduce((acc, current) => {
      acc[current] = `<div data-testid="${current}" />`;
      return acc;
    }, {});

    it('exist when the slot is present', async () => {
      mountComponent({ slots: slotMocks });

      await wrapper.vm.$nextTick();
      slotNames.forEach(name => {
        expect(findMetadataSlot(name).exists()).toBe(true);
      });
    });
  });
});
