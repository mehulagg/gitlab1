import { nextTick } from 'vue';
import { mount } from '@vue/test-utils';
import {
  Blob as BlobMock,
  SimpleViewerMock,
  RichViewerMock,
  RichBlobContentMock,
  SimpleBlobContentMock,
} from 'jest/blob/components/mock_data';
import SnippetBlobView from '~/snippets/components/snippet_blob_view.vue';
import BlobHeader from '~/blob/components/blob_header.vue';
import BlobContent from '~/blob/components/blob_content.vue';
import {
  BLOB_RENDER_EVENT_LOAD,
  BLOB_RENDER_EVENT_SHOW_SOURCE,
  BLOB_RENDER_ERRORS,
} from '~/blob/components/constants';
import { RichViewer, SimpleViewer } from '~/vue_shared/components/blob_viewers';
import { SNIPPET_VISIBILITY_PUBLIC } from '~/snippets/constants';

describe('Blob Embeddable', () => {
  let wrapper;
  const snippet = {
    id: 'gid://foo.bar/snippet',
    webUrl: 'https://foo.bar',
    visibilityLevel: SNIPPET_VISIBILITY_PUBLIC,
  };
  const dataMock = {
    activeViewerType: SimpleViewerMock.type,
  };

  function createComponent({
    snippetProps = {},
    data = dataMock,
    blob = BlobMock,
    contentLoading = false,
  } = {}) {
    const $apollo = {
      queries: {
        blobContent: {
          loading: contentLoading,
          refetch: jest.fn(),
          skip: true,
        },
      },
    };

    wrapper = mount(SnippetBlobView, {
      propsData: {
        snippet: {
          ...snippet,
          ...snippetProps,
        },
        blob,
      },
      data() {
        return {
          ...data,
        };
      },
      mocks: { $apollo },
    });
  }

  afterEach(() => {
    wrapper.destroy();
  });

  describe('rendering', () => {
    it('renders correct components', () => {
      createComponent();
      expect(wrapper.find(BlobHeader).exists()).toBe(true);
      expect(wrapper.find(BlobContent).exists()).toBe(true);
    });

    it('sets simple viewer correctly', () => {
      createComponent();
      expect(wrapper.find(SimpleViewer).exists()).toBe(true);
    });

    it('sets rich viewer correctly', () => {
      const data = { ...dataMock, activeViewerType: RichViewerMock.type };
      createComponent({
        data,
      });
      expect(wrapper.find(RichViewer).exists()).toBe(true);
    });

    it('correctly switches viewer type', () => {
      createComponent();
      expect(wrapper.find(SimpleViewer).exists()).toBe(true);

      wrapper.vm.switchViewer(RichViewerMock.type);

      return wrapper.vm
        .$nextTick()
        .then(() => {
          expect(wrapper.find(RichViewer).exists()).toBe(true);
          wrapper.vm.switchViewer(SimpleViewerMock.type);
        })
        .then(() => {
          expect(wrapper.find(SimpleViewer).exists()).toBe(true);
        });
    });

    it('passes information about render error down to blob header', () => {
      createComponent({
        blob: {
          ...BlobMock,
          simpleViewer: {
            ...SimpleViewerMock,
            renderError: BLOB_RENDER_ERRORS.REASONS.COLLAPSED.id,
          },
        },
      });

      expect(wrapper.find(BlobHeader).props('hasRenderError')).toBe(true);
    });

    describe('bob content in multi-file scenario', () => {
      const SimpleBlobContentMock2 = {
        node: {
          ...SimpleBlobContentMock.node,
          plainData: 'Another Plain Foo',
        },
      };
      const RichBlobContentMock2 = {
        node: {
          ...SimpleBlobContentMock.node,
          richData: 'Another Rich Foo',
        },
      };

      it.each`
        snippetBlobs                                       | description                                  | currentBlob              | expectedContent
        ${[SimpleBlobContentMock]}                         | ${'one existing textual blob'}               | ${SimpleBlobContentMock} | ${SimpleBlobContentMock.node.plainData}
        ${[RichBlobContentMock]}                           | ${'one existing rich blob'}                  | ${RichBlobContentMock}   | ${RichBlobContentMock.node.richData}
        ${[SimpleBlobContentMock, RichBlobContentMock]}    | ${'mixed blobs with current textual blob'}   | ${SimpleBlobContentMock} | ${SimpleBlobContentMock.node.plainData}
        ${[SimpleBlobContentMock, RichBlobContentMock]}    | ${'mixed blobs with current rich blob'}      | ${RichBlobContentMock}   | ${RichBlobContentMock.node.richData}
        ${[SimpleBlobContentMock, SimpleBlobContentMock2]} | ${'textual blobs with current textual blob'} | ${SimpleBlobContentMock} | ${SimpleBlobContentMock.node.plainData}
        ${[RichBlobContentMock, RichBlobContentMock2]}     | ${'rich blobs with current rich blob'}       | ${RichBlobContentMock}   | ${RichBlobContentMock.node.richData}
      `(
        'renders correct content for $description',
        async ({ snippetBlobs, currentBlob, expectedContent }) => {
          const apolloData = {
            snippets: {
              edges: [
                {
                  node: {
                    blobs: {
                      edges: snippetBlobs,
                    },
                  },
                },
              ],
            },
          };
          createComponent({
            blob: {
              ...BlobMock,
              path: currentBlob.node.path,
            },
          });

          // mimic apollo's update
          wrapper.setData({
            blobContent: wrapper.vm.onContentUpdate(apolloData),
          });

          await nextTick();

          const findContent = () => wrapper.find(BlobContent);

          expect(findContent().props('content')).toBe(expectedContent);
        },
      );
    });

    describe('URLS with hash', () => {
      beforeEach(() => {
        window.location.hash = '#LC2';
      });

      afterEach(() => {
        window.location.hash = '';
      });

      it('renders simple viewer by default if URL contains hash', () => {
        createComponent({
          data: {},
        });

        expect(wrapper.vm.activeViewerType).toBe(SimpleViewerMock.type);
        expect(wrapper.find(SimpleViewer).exists()).toBe(true);
      });

      describe('switchViewer()', () => {
        it('switches to the passed viewer', () => {
          createComponent();

          wrapper.vm.switchViewer(RichViewerMock.type);
          return wrapper.vm
            .$nextTick()
            .then(() => {
              expect(wrapper.vm.activeViewerType).toBe(RichViewerMock.type);
              expect(wrapper.find(RichViewer).exists()).toBe(true);

              wrapper.vm.switchViewer(SimpleViewerMock.type);
            })
            .then(() => {
              expect(wrapper.vm.activeViewerType).toBe(SimpleViewerMock.type);
              expect(wrapper.find(SimpleViewer).exists()).toBe(true);
            });
        });
      });
    });
  });

  describe('functionality', () => {
    describe('render error', () => {
      const findContentEl = () => wrapper.find(BlobContent);

      it('correctly sets blob on the blob-content-error component', () => {
        createComponent();
        expect(findContentEl().props('blob')).toEqual(BlobMock);
      });

      it(`refetches blob content on ${BLOB_RENDER_EVENT_LOAD} event`, () => {
        createComponent();

        expect(wrapper.vm.$apollo.queries.blobContent.refetch).not.toHaveBeenCalled();
        findContentEl().vm.$emit(BLOB_RENDER_EVENT_LOAD);
        expect(wrapper.vm.$apollo.queries.blobContent.refetch).toHaveBeenCalledTimes(1);
      });

      it(`sets '${SimpleViewerMock.type}' as active on ${BLOB_RENDER_EVENT_SHOW_SOURCE} event`, () => {
        createComponent({
          data: {
            activeViewerType: RichViewerMock.type,
          },
        });

        findContentEl().vm.$emit(BLOB_RENDER_EVENT_SHOW_SOURCE);
        expect(wrapper.vm.activeViewerType).toEqual(SimpleViewerMock.type);
      });
    });
  });
});
