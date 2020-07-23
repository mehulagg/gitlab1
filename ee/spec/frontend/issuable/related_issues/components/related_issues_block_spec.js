import { shallowMount, mount } from '@vue/test-utils';
import RelatedIssuesBlock from 'ee/related_issues/components/related_issues_block.vue';
import {
  issuable1,
  issuable2,
  issuable3,
} from 'jest/vue_shared/components/issue/related_issuable_mock_data';
import {
  linkedIssueTypesMap,
  linkedIssueTypesTextMap,
  PathIdSeparator,
} from 'ee/related_issues/constants';

describe('RelatedIssuesBlock', () => {
  let wrapper;

  afterEach(() => {
    wrapper.destroy();
  });

  describe('with defaults', () => {
    beforeEach(() => {
      wrapper = mount(RelatedIssuesBlock, {
        propsData: {
          pathIdSeparator: PathIdSeparator.Issue,
          issuableType: 'issue',
        },
      });
    });

    it('displays "Linked issues" in the header', () => {
      expect(wrapper.find('.card-title').text()).toContain('Linked issues');
    });

    it('unable to add new related issues', () => {
      expect(wrapper.vm.$refs.issueCountBadgeAddButton).toBeUndefined();
    });

    it('add related issues form is hidden', () => {
      expect(wrapper.contains('.js-add-related-issues-form-area')).toBe(false);
    });
  });

  describe('with headerText slot', () => {
    it('displays header text slot data', () => {
      const headerText = '<div>custom header text</div>';

      wrapper = shallowMount(RelatedIssuesBlock, {
        propsData: {
          pathIdSeparator: PathIdSeparator.Issue,
          issuableType: 'issue',
        },
        slots: { headerText },
      });

      expect(wrapper.find('.card-title').html()).toContain(headerText);
    });
  });

  describe('with isFetching=true', () => {
    beforeEach(() => {
      wrapper = mount(RelatedIssuesBlock, {
        propsData: {
          pathIdSeparator: PathIdSeparator.Issue,
          isFetching: true,
          issuableType: 'issue',
        },
      });
    });

    it('should show `...` badge count', () => {
      expect(wrapper.vm.badgeLabel).toBe('...');
    });
  });

  describe('with canAddRelatedIssues=true', () => {
    beforeEach(() => {
      wrapper = mount(RelatedIssuesBlock, {
        propsData: {
          pathIdSeparator: PathIdSeparator.Issue,
          canAdmin: true,
          issuableType: 'issue',
        },
      });
    });

    it('can add new related issues', () => {
      expect(wrapper.vm.$refs.issueCountBadgeAddButton).toBeDefined();
    });
  });

  describe('with isFormVisible=true', () => {
    beforeEach(() => {
      wrapper = mount(RelatedIssuesBlock, {
        propsData: {
          pathIdSeparator: PathIdSeparator.Issue,
          isFormVisible: true,
          issuableType: 'issue',
        },
      });
    });

    it('shows add related issues form', () => {
      expect(wrapper.contains('.js-add-related-issues-form-area')).toBe(true);
    });
  });

  describe('showCategorizedIssues prop', () => {
    const issueList = () => wrapper.findAll('.js-related-issues-token-list-item');
    const categorizedHeadings = () => wrapper.findAll('h4');
    const headingTextAt = (index) => categorizedHeadings().at(index).text();
    const mountComponent = (showCategorizedIssues) => {
      wrapper = mount(RelatedIssuesBlock, {
        propsData: {
          pathIdSeparator: PathIdSeparator.Issue,
          relatedIssues: [issuable1, issuable2, issuable3],
          issuableType: 'issue',
          showCategorizedIssues,
        },
      });
    };

    describe('when showCategorizedIssues=true', () => {
      beforeEach(() => mountComponent(true));

      it('should render issue tokens items', () => {
        expect(issueList()).toHaveLength(3);
      });

      it('shows "Blocks" heading', () => {
        const blocks = linkedIssueTypesTextMap[linkedIssueTypesMap.BLOCKS];

        expect(headingTextAt(0)).toBe(blocks);
      });

      it('shows "Is blocked by" heading', () => {
        const isBlockedBy = linkedIssueTypesTextMap[linkedIssueTypesMap.IS_BLOCKED_BY];

        expect(headingTextAt(1)).toBe(isBlockedBy);
      });

      it('shows "Relates to" heading', () => {
        const relatesTo = linkedIssueTypesTextMap[linkedIssueTypesMap.RELATES_TO];

        expect(headingTextAt(2)).toBe(relatesTo);
      });
    });

    describe('when showCategorizedIssues=false', () => {
      it('should render issues as a flat list with no header', () => {
        mountComponent(false);

        expect(issueList()).toHaveLength(3);
        expect(categorizedHeadings()).toHaveLength(0);
      });
    });
  });

  describe('renders correct icon when', () => {
    [
      {
        icon: 'issues',
        issuableType: 'issue',
      },
      {
        icon: 'epic',
        issuableType: 'epic',
      },
    ].forEach(({ issuableType, icon }) => {
      it(`issuableType=${issuableType} is passed`, () => {
        wrapper = mount(RelatedIssuesBlock, {
          propsData: {
            pathIdSeparator: PathIdSeparator.Issue,
            issuableType,
          },
        });

        expect(wrapper.contains(`.issue-count-badge-count .ic-${icon}`)).toBe(true);
      });
    });
  });
});
