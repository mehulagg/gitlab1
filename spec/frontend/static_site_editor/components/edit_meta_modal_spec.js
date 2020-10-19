import { shallowMount } from '@vue/test-utils';
import { GlModal } from '@gitlab/ui';
import { useLocalStorageSpy } from 'helpers/local_storage_helper';
import AccessorUtilities from '~/lib/utils/accessor';
import EditMetaModal from '~/static_site_editor/components/edit_meta_modal.vue';
import EditMetaControls from '~/static_site_editor/components/edit_meta_controls.vue';
import { MR_META_LOCAL_STORAGE_KEY } from '~/static_site_editor/constants';
import { sourcePath, mergeRequestMeta } from '../mock_data';

describe('~/static_site_editor/components/edit_meta_modal.vue', () => {
  useLocalStorageSpy();

  let wrapper;
  let resetCachedEditable;
  let mockEditMetaControlsInstance;
  const { title, description } = mergeRequestMeta;

  const buildWrapper = (propsData = {}) => {
    wrapper = shallowMount(EditMetaModal, {
      propsData: {
        sourcePath,
        ...propsData,
      },
    });
  };

  const buildMocks = () => {
    resetCachedEditable = jest.fn();
    mockEditMetaControlsInstance = { resetCachedEditable };
    wrapper.vm.$refs.editMetaControls = mockEditMetaControlsInstance;
  };

  const findGlModal = () => wrapper.find(GlModal);
  const findEditMetaControls = () => wrapper.find(EditMetaControls);

  beforeEach(() => {
    localStorage.setItem(MR_META_LOCAL_STORAGE_KEY);
  });

  beforeEach(() => {
    buildWrapper();
    buildMocks();

    return wrapper.vm.$nextTick();
  });

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  it('initializes initial merge request meta with local storage data', () => {
    const localStorageMeta = { title: 'stored title', description: 'stored description' };

    jest.spyOn(AccessorUtilities, 'isLocalStorageAccessSafe');

    AccessorUtilities.isLocalStorageAccessSafe.mockReturnValueOnce(true);

    localStorage.setItem(MR_META_LOCAL_STORAGE_KEY, JSON.stringify(localStorageMeta));

    wrapper.destroy();
    buildWrapper();

    expect(findEditMetaControls().props()).toEqual(localStorageMeta);
  });

  it('renders the modal', () => {
    expect(findGlModal().exists()).toBe(true);
  });

  it('renders the edit meta controls', () => {
    expect(findEditMetaControls().exists()).toBe(true);
  });

  it('contains the sourcePath in the title', () => {
    expect(findEditMetaControls().props('title')).toContain(sourcePath);
  });

  it('forwards the title prop', () => {
    expect(findEditMetaControls().props('title')).toBe(title);
  });

  it('forwards the description prop', () => {
    expect(findEditMetaControls().props('description')).toBe(description);
  });

  describe('when save button is clicked', () => {
    beforeEach(() => {
      findGlModal().vm.$emit('primary', mergeRequestMeta);
    });

    it('removes merge request meta from local storage', () => {
      expect(localStorage.removeItem).toHaveBeenCalledWith(MR_META_LOCAL_STORAGE_KEY);
    });

    it('emits the primary event with mergeRequestMeta', () => {
      expect(wrapper.emitted('primary')).toEqual([[mergeRequestMeta]]);
    });
  });

  it('emits the hide event', () => {
    findGlModal().vm.$emit('hide');
    expect(wrapper.emitted('hide')).toEqual([[]]);
  });

  it('stores merge request meta changes in local storage when changes happen', () => {
    const newMeta = { title: 'new title', description: 'new description' };

    findEditMetaControls().vm.$emit('updateSettings', newMeta);

    expect(localStorage.setItem).toHaveBeenCalledWith(
      MR_META_LOCAL_STORAGE_KEY,
      JSON.stringify(newMeta),
    );
  });
});
