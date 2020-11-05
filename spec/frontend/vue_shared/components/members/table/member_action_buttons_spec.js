import { shallowMount } from '@vue/test-utils';
import { MEMBER_TYPES } from '~/vue_shared/components/members/constants';
import { member as memberMock, group, invite, accessRequest } from '../mock_data';
import MemberActionButtons from '~/vue_shared/components/members/table/member_action_buttons.vue';
import UserActionButtons from '~/vue_shared/components/members/action_buttons/user_action_buttons.vue';
import GroupActionButtons from '~/vue_shared/components/members/action_buttons/group_action_buttons.vue';
import InviteActionButtons from '~/vue_shared/components/members/action_buttons/invite_action_buttons.vue';
import AccessRequestActionButtons from '~/vue_shared/components/members/action_buttons/access_request_action_buttons.vue';

describe('MemberActionButtons', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMount(MemberActionButtons, {
      propsData: {
        isCurrentUser: false,
        permissions: {
          canRemove: true,
        },
        ...propsData,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  test.each`
    memberType                    | member           | expectedComponent             | expectedComponentName
    ${MEMBER_TYPES.user}          | ${memberMock}    | ${UserActionButtons}          | ${'UserActionButtons'}
    ${MEMBER_TYPES.group}         | ${group}         | ${GroupActionButtons}         | ${'GroupActionButtons'}
    ${MEMBER_TYPES.invite}        | ${invite}        | ${InviteActionButtons}        | ${'InviteActionButtons'}
    ${MEMBER_TYPES.accessRequest} | ${accessRequest} | ${AccessRequestActionButtons} | ${'AccessRequestActionButtons'}
  `(
    'renders $expectedComponentName when `memberType` is $memberType',
    ({ memberType, member, expectedComponent }) => {
      createComponent({ memberType, member });

      expect(wrapper.find(expectedComponent).exists()).toBe(true);
    },
  );
});
