import { shallowMount } from '@vue/test-utils';
import resolveDiscussionButton from '~/notes/components/discussion_resolve_button.vue';

const buttonTitle = 'Resolve discussion';

describe('resolveDiscussionButton', () => {
  let wrapper;

  const resolveButton = () => wrapper.find('[data-testid="discussion-resolve-button"]');

  const factory = options => {
    wrapper = shallowMount(resolveDiscussionButton, {
      ...options,
    });
  };

  beforeEach(() => {
    factory({
      propsData: {
        isResolving: false,
        buttonTitle,
      },
    });
  });

  afterEach(() => {
    wrapper.destroy();
  });

  it('should emit a onClick event on button click', () => {
    resolveButton().trigger('click');

    return wrapper.vm.$nextTick().then(() => {
      expect(wrapper.emitted()).toEqual({});
    });
  });

  it('should contain the provided button title', () => {
    expect(resolveButton().text()).toContain(buttonTitle);
  });

  it('should show a loading spinner while resolving', () => {
    factory({
      propsData: {
        isResolving: true,
        buttonTitle,
      },
    });

    expect(resolveButton().exists()).toEqual(true);
  });

  it('should only show a loading spinner while resolving', () => {
    factory({
      propsData: {
        isResolving: false,
        buttonTitle,
      },
    });

    const button = wrapper.find({ ref: 'isResolvingIcon' });

    wrapper.vm.$nextTick(() => {
      expect(button.exists()).toEqual(false);
    });
  });
});
