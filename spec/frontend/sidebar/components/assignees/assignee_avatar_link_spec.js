import { shallowMount } from '@vue/test-utils';
import { TEST_HOST } from 'helpers/test_constants';
import AssigneeAvatar from '~/sidebar/components/assignees/assignee_avatar.vue';
import AssigneeAvatarLink, {
  generateAssigneeTooltip,
} from '~/sidebar/components/assignees/assignee_avatar_link.vue';
import userDataMock from '../../user_data_mock';

const TOOLTIP_PLACEMENT = 'bottom';
const { name: USER_NAME } = userDataMock();
const TEST_ISSUABLE_TYPE = 'merge_request';

describe('AssigneeAvatarLink component', () => {
  let wrapper;

  function createComponent(props = {}) {
    const propsData = {
      user: userDataMock(),
      showLess: true,
      rootPath: TEST_HOST,
      tooltipPlacement: TOOLTIP_PLACEMENT,
      singleUser: false,
      issuableType: TEST_ISSUABLE_TYPE,
      ...props,
    };

    wrapper = shallowMount(AssigneeAvatarLink, {
      propsData,
    });
  }

  afterEach(() => {
    wrapper.destroy();
  });

  const findTooltipText = () => wrapper.attributes('title');

  it('has the root url present in the assigneeUrl method', () => {
    createComponent();

    expect(wrapper.attributes().href).toEqual(userDataMock().web_url);
  });

  it('renders assignee avatar', () => {
    createComponent();

    expect(wrapper.find(AssigneeAvatar).props()).toEqual(
      expect.objectContaining({
        issuableType: TEST_ISSUABLE_TYPE,
        user: userDataMock(),
      }),
    );
  });

  describe.each`
    issuableType       | tooltipHasName | canMerge | expected
    ${'merge_request'} | ${true}        | ${true}  | ${USER_NAME}
    ${'merge_request'} | ${true}        | ${false} | ${`${USER_NAME} (cannot merge)`}
    ${'merge_request'} | ${false}       | ${true}  | ${''}
    ${'merge_request'} | ${false}       | ${false} | ${'Cannot merge'}
    ${'issue'}         | ${true}        | ${true}  | ${USER_NAME}
    ${'issue'}         | ${true}        | ${false} | ${USER_NAME}
    ${'issue'}         | ${false}       | ${true}  | ${''}
    ${'issue'}         | ${false}       | ${false} | ${''}
  `(
    'with $issuableType and tooltipHasName=$tooltipHasName and canMerge=$canMerge',
    ({ issuableType, tooltipHasName, canMerge, expected }) => {
      beforeEach(() => {
        createComponent({
          issuableType,
          tooltipHasName,
          user: {
            ...userDataMock(),
            can_merge: canMerge,
          },
        });
      });

      it('sets tooltip', () => {
        expect(findTooltipText()).toBe(expected);
      });
    },
  );

  describe.each`
    tooltipHasName | availability | cannotMerge | expected
    ${true}        | ${'Busy'}    | ${true}     | ${'Root (Busy) (cannot merge)'}
    ${true}        | ${'Busy'}    | ${false}    | ${'Root (Busy)'}
    ${true}        | ${''}        | ${true}     | ${'Root (cannot merge)'}
    ${true}        | ${''}        | ${false}    | ${'Root'}
    ${false}       | ${'Busy'}    | ${true}     | ${'Cannot merge'}
    ${false}       | ${'Busy'}    | ${false}    | ${''}
    ${false}       | ${''}        | ${true}     | ${'Cannot merge'}
    ${false}       | ${''}        | ${false}    | ${''}
  `(
    "with $tooltipHasName and availability='$availability' and cannotMerge=$cannotMerge",
    ({ tooltipHasName, availability, cannotMerge, expected }) => {
      it('generates the tooltip text', () => {
        expect(
          generateAssigneeTooltip({ name: USER_NAME, availability, cannotMerge, tooltipHasName }),
        ).toBe(expected);
      });
    },
  );
});
