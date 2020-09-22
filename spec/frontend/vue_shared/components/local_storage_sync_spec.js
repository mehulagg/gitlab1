import { shallowMount } from '@vue/test-utils';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';

describe('Local Storage Sync', () => {
  let wrapper;

  const createComponent = ({ props = {}, slots = {} } = {}) => {
    wrapper = shallowMount(LocalStorageSync, {
      propsData: props,
      slots,
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
    wrapper = null;
    localStorage.clear();
  });

  it('is a renderless component', () => {
    const html = '<div class="test-slot"></div>';
    createComponent({
      props: {
        storageKey: 'key',
      },
      slots: {
        default: html,
      },
    });

    expect(wrapper.html()).toBe(html);
  });

  describe('localStorage empty', () => {
    const storageKey = 'issue_list_order';

    it('does not emit input event', () => {
      createComponent({
        props: {
          storageKey,
          value: 'ascending',
        },
      });

      expect(wrapper.emitted('input')).toBeFalsy();
    });

    it('saves updated value to localStorage', () => {
      createComponent({
        props: {
          storageKey,
          value: 'ascending',
        },
      });

      const newValue = 'descending';
      wrapper.setProps({
        value: newValue,
      });

      return wrapper.vm.$nextTick().then(() => {
        expect(localStorage.getItem(storageKey)).toBe(newValue);
      });
    });

    it('does not save default value', () => {
      const value = 'ascending';

      createComponent({
        props: {
          storageKey,
          value,
        },
      });

      expect(localStorage.getItem(storageKey)).toBe(null);
    });
  });

  describe('localStorage has saved value', () => {
    const storageKey = 'issue_list_order_by';
    const savedValue = 'last_updated';

    beforeEach(() => {
      localStorage.setItem(storageKey, savedValue);
    });

    it('emits input event with saved value', () => {
      createComponent({
        props: {
          storageKey,
          value: 'ascending',
        },
      });

      expect(wrapper.emitted('input')[0][0]).toBe(savedValue);
    });

    it('does not overwrite localStorage with prop value', () => {
      createComponent({
        props: {
          storageKey,
          value: 'created',
        },
      });

      expect(localStorage.getItem(storageKey)).toBe(savedValue);
    });

    it('updating the value updates localStorage', () => {
      createComponent({
        props: {
          storageKey,
          value: 'created',
        },
      });

      const newValue = 'last_updated';
      wrapper.setProps({
        value: newValue,
      });

      return wrapper.vm.$nextTick().then(() => {
        expect(localStorage.getItem(storageKey)).toBe(newValue);
      });
    });
  });

  describe('with default props', () => {
    it.each([1, true, [], {}])(
      'throws a validation error when passed in a non-string value',
      nonStringValue => {
        expect(() => {
          createComponent({
            props: {
              storageKey: 'storageKey',
              value: nonStringValue,
            },
          });
        }).toThrow(/invalid prop/i);
      },
    );
  });

  describe('with "json" prop set to "true"', () => {
    const storageKey = 'storageKey';

    describe.each`
      value             | serializedValue
      ${null}           | ${'null'}
      ${''}             | ${'""'}
      ${true}           | ${'true'}
      ${false}          | ${'false'}
      ${42}             | ${'42'}
      ${'42'}           | ${'"42"'}
      ${['test']}       | ${'["test"]'}
      ${{ foo: 'bar' }} | ${'{"foo":"bar"}'}
    `('given $value', ({ value, serializedValue }) => {
      describe('is a new value', () => {
        beforeEach(() => {
          createComponent({
            props: {
              storageKey,
              value: 'initial',
              json: true,
            },
          });

          wrapper.setProps({ value });
        });

        it('serializes the value correctly to localStorage', () => {
          expect(localStorage.getItem(storageKey)).toBe(serializedValue);
        });
      });

      describe('is already stored', () => {
        beforeEach(() => {
          localStorage.setItem(storageKey, serializedValue);

          createComponent({
            props: {
              storageKey,
              value: 'initial',
              json: true,
            },
          });
        });

        it('emits an input event with the deserialized value', () => {
          expect(wrapper.emitted('input')).toEqual([[value]]);
        });
      });
    });
  });
});
