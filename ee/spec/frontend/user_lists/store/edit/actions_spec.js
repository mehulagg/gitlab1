import Api from 'ee/api';
import { redirectTo } from '~/lib/utils/url_utility';
import createState from 'ee/user_lists/store/edit/state';
import * as types from 'ee/user_lists/store/edit/mutation_types';
import * as actions from 'ee/user_lists/store/edit/actions';
import testAction from 'helpers/vuex_action_helper';
import { userList } from '../../../feature_flags/mock_data';

jest.mock('ee/api');
jest.mock('~/lib/utils/url_utility');

describe('User Lists Edit Actions', () => {
  let state;

  beforeEach(() => {
    state = createState({ projectId: '1', userListIid: '2' });
  });

  describe('fetchUserList', () => {
    describe('success', () => {
      beforeEach(() => {
        Api.fetchFeatureFlagUserList.mockResolvedValue({ data: userList });
      });

      it('should commit RECEIVE_USER_LIST_SUCCESS', () => {
        return testAction(
          actions.fetchUserList,
          undefined,
          state,
          [
            { type: types.REQUEST_USER_LIST },
            { type: types.RECEIVE_USER_LIST_SUCCESS, payload: userList },
          ],
          [],
          () => expect(Api.fetchFeatureFlagUserList).toHaveBeenCalledWith('1', '2'),
        );
      });
    });

    describe('error', () => {
      let error;
      beforeEach(() => {
        error = { response: { data: { message: ['error'] } } };
        Api.fetchFeatureFlagUserList.mockRejectedValue(error);
      });

      it('should commit RECEIVE_USER_LIST_ERROR', () => {
        return testAction(
          actions.fetchUserList,
          undefined,
          state,
          [
            { type: types.REQUEST_USER_LIST },
            { type: types.RECEIVE_USER_LIST_ERROR, payload: ['error'] },
          ],
          [],
          () => expect(Api.fetchFeatureFlagUserList).toHaveBeenCalledWith('1', '2'),
        );
      });
    });
  });

  describe('dismissErrorAlert', () => {
    it('should commit DISMISS_ERROR_ALERT', () => {
      return testAction(actions.dismissErrorAlert, undefined, state, [
        { type: types.DISMISS_ERROR_ALERT },
      ]);
    });
  });

  describe('updateUserList', () => {
    let updatedList;

    beforeEach(() => {
      updatedList = {
        ...userList,
        name: 'new',
      };
    });
    describe('success', () => {
      beforeEach(() => {
        Api.updateFeatureFlagUserList.mockResolvedValue({ data: userList });
        state.userList = userList;
      });

      it('should commit RECEIVE_USER_LIST_SUCCESS', () => {
        return testAction(actions.updateUserList, updatedList, state, [], [], () => {
          expect(Api.updateFeatureFlagUserList).toHaveBeenCalledWith('1', {
            name: updatedList.name,
          });
          expect(redirectTo).toHaveBeenCalledWith(userList.path);
        });
      });
    });

    describe('error', () => {
      let error;

      beforeEach(() => {
        error = { message: 'error' };
        Api.updateFeatureFlagUserList.mockRejectedValue(error);
      });

      it('should commit RECEIVE_USER_LIST_ERROR', () => {
        return testAction(
          actions.updateUserList,
          updatedList,
          state,
          [{ type: types.RECEIVE_USER_LIST_ERROR, payload: ['error'] }],
          [],
          () =>
            expect(Api.updateFeatureFlagUserList).toHaveBeenCalledWith('1', {
              name: updatedList.name,
            }),
        );
      });
    });
  });
});
