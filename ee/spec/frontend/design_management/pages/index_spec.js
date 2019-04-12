import { shallowMount } from '@vue/test-utils';
import Index from 'ee/design_management/pages/index.vue';
import UploadForm from 'ee/design_management/components/upload/form.vue';
import uploadDesignQuery from 'ee/design_management/queries/uploadDesign.graphql';

describe('Design management index page', () => {
  let mutate;
  let vm;

  function createComponent(loading = false, designs = []) {
    mutate = jest.fn(() => Promise.resolve());
    const $apollo = {
      queries: {
        designs: {
          loading,
        },
        permissions: {
          loading,
        },
      },
      mutate,
    };

    vm = shallowMount(Index, {
      mocks: { $apollo },
      stubs: ['router-view'],
    });

    vm.setData({
      designs,
      permissions: {
        createDesign: true,
      },
    });
  }

  afterEach(() => {
    vm.destroy();
  });

  describe('designs', () => {
    it('renders loading icon', () => {
      createComponent(true);

      expect(vm.element).toMatchSnapshot();
    });

    it('renders error', () => {
      createComponent();

      vm.setData({ error: true });

      expect(vm.element).toMatchSnapshot();
    });

    it('renders empty text', () => {
      createComponent();

      expect(vm.element).toMatchSnapshot();
    });

    it('renders designs list', () => {
      createComponent(false, ['design']);

      expect(vm.element).toMatchSnapshot();
    });
  });

  describe('upload form', () => {
    it('hides upload form', () => {
      createComponent();

      expect(vm.find(UploadForm).exists()).toBe(false);
    });

    it('renders upload form', () => {
      createComponent(false, ['design']);

      expect(vm.find(UploadForm).exists()).toBe(true);
    });
  });

  describe('onUploadDesign', () => {
    it('calls apollo mutate', () => {
      createComponent();

      return vm.vm
        .onUploadDesign([
          {
            name: 'test',
          },
        ])
        .then(() => {
          expect(mutate).toHaveBeenCalledWith({
            mutation: uploadDesignQuery,
            variables: {
              files: [{ name: 'test' }],
            },
            optimisticResponse: {
              __typename: 'Mutation',
              uploadDesign: [
                {
                  __typename: 'Design',
                  id: -1,
                  image: '',
                  name: 'test',
                  commentsCount: 0,
                  updatedAt: expect.any(String),
                },
              ],
            },
          });
        });
    });

    it('does not call apollo mutate if createDesign is false', () => {
      createComponent();

      vm.setData({
        permissions: {
          createDesign: false,
        },
      });

      vm.vm.onUploadDesign([]);

      expect(mutate).not.toHaveBeenCalled();
    });

    it('sets isSaving', () => {
      createComponent();

      const uploadDesign = vm.vm.onUploadDesign([
        {
          name: 'test',
        },
      ]);

      expect(vm.vm.isSaving).toBe(true);

      return uploadDesign.then(() => {
        expect(vm.vm.isSaving).toBe(false);
      });
    });
  });
});
