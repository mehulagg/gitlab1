import MockAdapter from 'axios-mock-adapter';
import {
  setHeadBlobPath,
  setBaseBlobPath,
  setVulnerabilityFeedbackPath,
  setVulnerabilityFeedbackHelpPath,
  setPipelineId,
  setCanCreateIssuePermission,
  setCanCreateFeedbackPermission,
  openModal,
  setModalData,
  requestDismissVulnerability,
  receiveDismissVulnerability,
  receiveDismissVulnerabilityError,
  dismissVulnerability,
  revertDismissVulnerability,
  requestCreateIssue,
  receiveCreateIssue,
  receiveCreateIssueError,
  createNewIssue,
  downloadPatch,
  requestCreateMergeRequest,
  receiveCreateMergeRequestSuccess,
  receiveCreateMergeRequestError,
  createMergeRequest,
  addDismissalComment,
  receiveAddDismissalCommentError,
  receiveAddDismissalCommentSuccess,
  requestAddDismissalComment,
  deleteDismissalComment,
  receiveDeleteDismissalCommentError,
  receiveDeleteDismissalCommentSuccess,
  requestDeleteDismissalComment,
  showDismissalDeleteButtons,
  hideDismissalDeleteButtons,
} from 'ee/vue_shared/security_reports/store/actions';
import * as types from 'ee/vue_shared/security_reports/store/mutation_types';
import state from 'ee/vue_shared/security_reports/store/state';
import testAction from 'helpers/vuex_action_helper';
import axios from '~/lib/utils/axios_utils';
import toasted from '~/vue_shared/plugins/global_toast';

// Mock bootstrap modal implementation
jest.mock('jquery', () => () => ({
  modal: jest.fn(),
}));
jest.mock('~/lib/utils/url_utility', () => ({
  visitUrl: jest.fn(),
}));

jest.mock('~/vue_shared/plugins/global_toast', () => jest.fn());

const createVulnerability = options => ({
  ...options,
});

const createNonDismissedVulnerability = options =>
  createVulnerability({
    ...options,
    isDismissed: false,
    dismissalFeedback: null,
  });

const createDismissedVulnerability = options =>
  createVulnerability({
    ...options,
    isDismissed: true,
  });

describe('security reports actions', () => {
  let mockedState;
  let mock;

  beforeEach(() => {
    mockedState = state();
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
    toasted.mockClear();
  });

  describe('setHeadBlobPath', () => {
    it('should commit set head blob path', done => {
      testAction(
        setHeadBlobPath,
        'path',
        mockedState,
        [
          {
            type: types.SET_HEAD_BLOB_PATH,
            payload: 'path',
          },
        ],
        [],
        done,
      );
    });
  });

  describe('setBaseBlobPath', () => {
    it('should commit set head blob path', done => {
      testAction(
        setBaseBlobPath,
        'path',
        mockedState,
        [
          {
            type: types.SET_BASE_BLOB_PATH,
            payload: 'path',
          },
        ],
        [],
        done,
      );
    });
  });

  describe('setVulnerabilityFeedbackPath', () => {
    it('should commit set vulnerabulity feedback path', done => {
      testAction(
        setVulnerabilityFeedbackPath,
        'path',
        mockedState,
        [
          {
            type: types.SET_VULNERABILITY_FEEDBACK_PATH,
            payload: 'path',
          },
        ],
        [],
        done,
      );
    });
  });

  describe('setVulnerabilityFeedbackHelpPath', () => {
    it('should commit set vulnerabulity feedback help path', done => {
      testAction(
        setVulnerabilityFeedbackHelpPath,
        'path',
        mockedState,
        [
          {
            type: types.SET_VULNERABILITY_FEEDBACK_HELP_PATH,
            payload: 'path',
          },
        ],
        [],
        done,
      );
    });
  });

  describe('setPipelineId', () => {
    it('should commit set vulnerability feedback path', done => {
      testAction(
        setPipelineId,
        123,
        mockedState,
        [
          {
            type: types.SET_PIPELINE_ID,
            payload: 123,
          },
        ],
        [],
        done,
      );
    });
  });

  describe('setCanCreateIssuePermission', () => {
    it('should commit set can create issue permission', done => {
      testAction(
        setCanCreateIssuePermission,
        true,
        mockedState,
        [
          {
            type: types.SET_CAN_CREATE_ISSUE_PERMISSION,
            payload: true,
          },
        ],
        [],
        done,
      );
    });
  });

  describe('setCanCreateFeedbackPermission', () => {
    it('should commit set can create feedback permission', done => {
      testAction(
        setCanCreateFeedbackPermission,
        true,
        mockedState,
        [
          {
            type: types.SET_CAN_CREATE_FEEDBACK_PERMISSION,
            payload: true,
          },
        ],
        [],
        done,
      );
    });
  });

  describe('openModal', () => {
    it('dispatches setModalData action', done => {
      testAction(
        openModal,
        { issue: { id: 1 }, status: 'failed' },
        mockedState,
        [],
        [
          {
            type: 'setModalData',
            payload: { issue: { id: 1 }, status: 'failed' },
          },
        ],
        done,
      );
    });
  });

  describe('setModalData', () => {
    it('commits set issue modal data', done => {
      testAction(
        setModalData,
        { issue: { id: 1 }, status: 'success' },
        mockedState,
        [
          {
            type: types.SET_ISSUE_MODAL_DATA,
            payload: { issue: { id: 1 }, status: 'success' },
          },
        ],
        [],
        done,
      );
    });
  });

  describe('requestDismissVulnerability', () => {
    it('commits request dismiss issue', done => {
      testAction(
        requestDismissVulnerability,
        null,
        mockedState,
        [
          {
            type: types.REQUEST_DISMISS_VULNERABILITY,
          },
        ],
        [],
        done,
      );
    });
  });

  describe('receiveDismissVulnerability', () => {
    it(`should pass the payload to the ${types.RECEIVE_DISMISS_VULNERABILITY_SUCCESS} mutation`, done => {
      const payload = createDismissedVulnerability();

      testAction(
        receiveDismissVulnerability,
        payload,
        mockedState,
        [
          {
            type: types.RECEIVE_DISMISS_VULNERABILITY_SUCCESS,
            payload,
          },
        ],
        [],
        done,
      );
    });
  });

  describe('receiveDismissVulnerabilityError', () => {
    it('commits receive dismiss issue error with payload', done => {
      testAction(
        receiveDismissVulnerabilityError,
        'error',
        mockedState,
        [
          {
            type: types.RECEIVE_DISMISS_VULNERABILITY_ERROR,
            payload: 'error',
          },
        ],
        [],
        done,
      );
    });
  });

  describe('dismissVulnerability', () => {
    describe('with success', () => {
      let payload;
      let dismissalFeedback;

      beforeEach(() => {
        dismissalFeedback = {
          foo: 'bar',
        };
        payload = createDismissedVulnerability({
          ...mockedState.modal.vulnerability,
          dismissalFeedback,
        });
        mock.onPost('dismiss_vulnerability_path').reply(200, dismissalFeedback);
        mockedState.createVulnerabilityFeedbackDismissalPath = 'dismiss_vulnerability_path';
      });

      it(`should dispatch receiveDismissVulnerability`, done => {
        testAction(
          dismissVulnerability,
          payload,
          mockedState,
          [],
          [
            {
              type: 'requestDismissVulnerability',
            },
            {
              type: 'closeDismissalCommentBox',
            },
            {
              type: 'receiveDismissVulnerability',
              payload,
            },
          ],
          done,
        );
      });

      it('show dismiss vulnerability toast message', done => {
        const checkToastMessage = () => {
          expect(toasted).toHaveBeenCalledTimes(1);
          done();
        };

        testAction(
          dismissVulnerability,
          payload,
          mockedState,
          [],
          [
            {
              type: 'requestDismissVulnerability',
            },
            {
              type: 'closeDismissalCommentBox',
            },
            {
              type: 'receiveDismissVulnerability',
              payload,
            },
          ],
          checkToastMessage,
        );
      });
    });

    it('with error should dispatch `receiveDismissVulnerabilityError`', done => {
      mock.onPost('dismiss_vulnerability_path').reply(500, {});
      mockedState.vulnerabilityFeedbackPath = 'dismiss_vulnerability_path';

      testAction(
        dismissVulnerability,
        null,
        mockedState,
        [],
        [
          {
            type: 'requestDismissVulnerability',
          },
          {
            type: 'receiveDismissVulnerabilityError',
            payload: 'There was an error dismissing the vulnerability. Please try again.',
          },
        ],
        done,
      );
    });
  });

  describe('addDismissalComment', () => {
    const vulnerability = {
      id: 0,
      vulnerability_feedback_dismissal_path: 'foo',
      dismissalFeedback: { id: 1 },
    };
    const data = { vulnerability };
    const url = `${state.createVulnerabilityFeedbackDismissalPath}/${vulnerability.dismissalFeedback.id}`;
    const comment = 'Well, we’re back in the car again.';

    describe('on success', () => {
      beforeEach(() => {
        mock.onPatch(url).replyOnce(200, data);
      });

      it('should dispatch the request and success actions', done => {
        testAction(
          addDismissalComment,
          { comment },
          { modal: { vulnerability } },
          [],
          [
            { type: 'requestAddDismissalComment' },
            { type: 'closeDismissalCommentBox' },
            {
              type: 'receiveAddDismissalCommentSuccess',
              payload: { data },
            },
          ],
          done,
        );
      });

      it('should show added dismissal comment toast message', done => {
        const checkToastMessage = () => {
          expect(toasted).toHaveBeenCalledTimes(1);
          done();
        };

        testAction(
          addDismissalComment,
          { comment },
          { modal: { vulnerability } },
          [],
          [
            { type: 'requestAddDismissalComment' },
            { type: 'closeDismissalCommentBox' },
            {
              type: 'receiveAddDismissalCommentSuccess',
              payload: { data },
            },
          ],
          checkToastMessage,
        );
      });
    });

    describe('on error', () => {
      beforeEach(() => {
        mock.onPatch(url).replyOnce(404);
      });

      it('should dispatch the request and error actions', done => {
        testAction(
          addDismissalComment,
          { comment },
          { modal: { vulnerability } },
          [],
          [
            { type: 'requestAddDismissalComment' },
            {
              type: 'receiveAddDismissalCommentError',
              payload: 'There was an error adding the comment.',
            },
          ],
          done,
        );
      });
    });

    describe('receiveAddDismissalCommentSuccess', () => {
      it('should commit the success mutation', done => {
        testAction(
          receiveAddDismissalCommentSuccess,
          { data },
          state,
          [{ type: types.RECEIVE_ADD_DISMISSAL_COMMENT_SUCCESS, payload: { data } }],
          [],
          done,
        );
      });
    });

    describe('receiveAddDismissalCommentError', () => {
      it('should commit the error mutation', done => {
        testAction(
          receiveAddDismissalCommentError,
          {},
          state,
          [
            {
              type: types.RECEIVE_ADD_DISMISSAL_COMMENT_ERROR,
              payload: {},
            },
          ],
          [],
          done,
        );
      });
    });

    describe('requestAddDismissalComment', () => {
      it('should commit the request mutation', done => {
        testAction(
          requestAddDismissalComment,
          {},
          state,
          [{ type: types.REQUEST_ADD_DISMISSAL_COMMENT }],
          [],
          done,
        );
      });
    });
  });

  describe('deleteDismissalComment', () => {
    const vulnerability = {
      id: 0,
      vulnerability_feedback_dismissal_path: 'foo',
      dismissalFeedback: { id: 1 },
    };
    const data = { vulnerability };
    const url = `${state.createVulnerabilityFeedbackDismissalPath}/${vulnerability.dismissalFeedback.id}`;
    const comment = '';

    describe('on success', () => {
      beforeEach(() => {
        mock.onPatch(url).replyOnce(200, data);
      });

      it('should dispatch the request and success actions', done => {
        testAction(
          deleteDismissalComment,
          { comment },
          { modal: { vulnerability } },
          [],
          [
            { type: 'requestDeleteDismissalComment' },
            { type: 'closeDismissalCommentBox' },
            {
              type: 'receiveDeleteDismissalCommentSuccess',
              payload: { data },
            },
          ],
          done,
        );
      });

      it('should show deleted dismissal comment toast message', done => {
        const checkToastMessage = () => {
          expect(toasted).toHaveBeenCalledTimes(1);
          done();
        };

        testAction(
          deleteDismissalComment,
          { comment },
          { modal: { vulnerability } },
          [],
          [
            { type: 'requestDeleteDismissalComment' },
            { type: 'closeDismissalCommentBox' },
            {
              type: 'receiveDeleteDismissalCommentSuccess',
              payload: { data },
            },
          ],
          checkToastMessage,
        );
      });
    });

    describe('on error', () => {
      beforeEach(() => {
        mock.onPatch(url).replyOnce(404);
      });

      it('should dispatch the request and error actions', done => {
        testAction(
          deleteDismissalComment,
          { comment },
          { modal: { vulnerability } },
          [],
          [
            { type: 'requestDeleteDismissalComment' },
            {
              type: 'receiveDeleteDismissalCommentError',
              payload: 'There was an error deleting the comment.',
            },
          ],
          done,
        );
      });
    });

    describe('receiveDeleteDismissalCommentSuccess', () => {
      it('should commit the success mutation', done => {
        testAction(
          receiveDeleteDismissalCommentSuccess,
          { data },
          state,
          [{ type: types.RECEIVE_DELETE_DISMISSAL_COMMENT_SUCCESS, payload: { data } }],
          [],
          done,
        );
      });
    });

    describe('receiveDeleteDismissalCommentError', () => {
      it('should commit the error mutation', done => {
        testAction(
          receiveDeleteDismissalCommentError,
          {},
          state,
          [
            {
              type: types.RECEIVE_DELETE_DISMISSAL_COMMENT_ERROR,
              payload: {},
            },
          ],
          [],
          done,
        );
      });
    });

    describe('requestDeleteDismissalComment', () => {
      it('should commit the request mutation', done => {
        testAction(
          requestDeleteDismissalComment,
          {},
          state,
          [{ type: types.REQUEST_DELETE_DISMISSAL_COMMENT }],
          [],
          done,
        );
      });
    });
  });

  describe('showDismissalDeleteButtons', () => {
    it('commits show dismissal delete buttons', done => {
      testAction(
        showDismissalDeleteButtons,
        null,
        mockedState,
        [
          {
            type: types.SHOW_DISMISSAL_DELETE_BUTTONS,
          },
        ],
        [],
        done,
      );
    });
  });

  describe('hideDismissalDeleteButtons', () => {
    it('commits hide dismissal delete buttons', done => {
      testAction(
        hideDismissalDeleteButtons,
        null,
        mockedState,
        [
          {
            type: types.HIDE_DISMISSAL_DELETE_BUTTONS,
          },
        ],
        [],
        done,
      );
    });
  });

  describe('revertDismissVulnerability', () => {
    describe('with success', () => {
      let payload;

      beforeEach(() => {
        mock.onDelete('dismiss_vulnerability_path/123').reply(200, {});
        mockedState.modal.vulnerability.dismissalFeedback = {
          id: 123,
          destroy_vulnerability_feedback_dismissal_path: 'dismiss_vulnerability_path/123',
        };
        payload = createNonDismissedVulnerability({ ...mockedState.modal.vulnerability });
      });

      it('should dispatch `receiveDismissVulnerability`', done => {
        testAction(
          revertDismissVulnerability,
          payload,
          mockedState,
          [],
          [
            {
              type: 'requestDismissVulnerability',
            },
            {
              type: 'receiveDismissVulnerability',
              payload,
            },
          ],
          done,
        );
      });
    });

    it('with error should dispatch `receiveDismissVulnerabilityError`', done => {
      mock.onDelete('dismiss_vulnerability_path/123').reply(500, {});
      mockedState.modal.vulnerability.dismissalFeedback = { id: 123 };
      mockedState.createVulnerabilityFeedbackDismissalPath = 'dismiss_vulnerability_path';

      testAction(
        revertDismissVulnerability,
        null,
        mockedState,
        [],
        [
          {
            type: 'requestDismissVulnerability',
          },
          {
            type: 'receiveDismissVulnerabilityError',
            payload: 'There was an error reverting the dismissal. Please try again.',
          },
        ],
        done,
      );
    });
  });

  describe('requestCreateIssue', () => {
    it('commits request create issue', done => {
      testAction(
        requestCreateIssue,
        null,
        mockedState,
        [
          {
            type: types.REQUEST_CREATE_ISSUE,
          },
        ],
        [],
        done,
      );
    });
  });

  describe('receiveCreateIssue', () => {
    it('commits receive create issue', done => {
      testAction(
        receiveCreateIssue,
        null,
        mockedState,
        [
          {
            type: types.RECEIVE_CREATE_ISSUE_SUCCESS,
          },
        ],
        [],
        done,
      );
    });
  });

  describe('receiveCreateIssueError', () => {
    it('commits receive create issue error with payload', done => {
      testAction(
        receiveCreateIssueError,
        'error',
        mockedState,
        [
          {
            type: types.RECEIVE_CREATE_ISSUE_ERROR,
            payload: 'error',
          },
        ],
        [],
        done,
      );
    });
  });

  describe('createNewIssue', () => {
    it('with success should dispatch `requestCreateIssue` and `receiveCreateIssue`', done => {
      mock.onPost('create_issue_path').reply(200, { issue_path: 'new_issue' });
      mockedState.createVulnerabilityFeedbackIssuePath = 'create_issue_path';

      testAction(
        createNewIssue,
        null,
        mockedState,
        [],
        [
          {
            type: 'requestCreateIssue',
          },
          {
            type: 'receiveCreateIssue',
          },
        ],
        done,
      );
    });

    it('with error should dispatch `receiveCreateIssueError`', done => {
      mock.onPost('create_issue_path').reply(500, {});
      mockedState.vulnerabilityFeedbackPath = 'create_issue_path';

      testAction(
        createNewIssue,
        null,
        mockedState,
        [],
        [
          {
            type: 'requestCreateIssue',
          },
          {
            type: 'receiveCreateIssueError',
            payload: 'There was an error creating the issue. Please try again.',
          },
        ],
        done,
      );
    });
  });

  describe('downloadPatch', () => {
    it('creates a download link and clicks on it to download the file', () => {
      jest.spyOn(document, 'createElement');
      jest.spyOn(document.body, 'appendChild');
      jest.spyOn(document.body, 'removeChild');

      downloadPatch({
        state: {
          modal: {
            vulnerability: {
              remediations: [
                {
                  diff: 'abcdef',
                },
              ],
            },
          },
        },
      });

      expect(document.createElement).toHaveBeenCalledTimes(1);
      expect(document.body.appendChild).toHaveBeenCalledTimes(1);
      expect(document.body.removeChild).toHaveBeenCalledTimes(1);
    });
  });

  describe('requestCreateMergeRequest', () => {
    it('commits request create merge request', done => {
      testAction(
        requestCreateMergeRequest,
        null,
        mockedState,
        [
          {
            type: types.REQUEST_CREATE_MERGE_REQUEST,
          },
        ],
        [],
        done,
      );
    });
  });

  describe('receiveCreateMergeRequestSuccess', () => {
    it('commits receive create merge request', done => {
      const data = { foo: 'bar' };

      testAction(
        receiveCreateMergeRequestSuccess,
        data,
        mockedState,
        [
          {
            type: types.RECEIVE_CREATE_MERGE_REQUEST_SUCCESS,
            payload: data,
          },
        ],
        [],
        done,
      );
    });
  });

  describe('receiveCreateMergeRequestError', () => {
    it('commits receive create merge request error', done => {
      testAction(
        receiveCreateMergeRequestError,
        '',
        mockedState,
        [
          {
            type: types.RECEIVE_CREATE_MERGE_REQUEST_ERROR,
          },
        ],
        [],
        done,
      );
    });
  });

  describe('createMergeRequest', () => {
    it('with success should dispatch `receiveCreateMergeRequestSuccess`', done => {
      const data = { merge_request_path: 'fakepath.html' };
      mockedState.createVulnerabilityFeedbackMergeRequestPath = 'create_merge_request_path';
      mock.onPost('create_merge_request_path').reply(200, data);

      testAction(
        createMergeRequest,
        null,
        mockedState,
        [],
        [
          {
            type: 'requestCreateMergeRequest',
          },
          {
            type: 'receiveCreateMergeRequestSuccess',
            payload: data,
          },
        ],
        done,
      );
    });

    it('with error should dispatch `receiveCreateMergeRequestError`', done => {
      mock.onPost('create_merge_request_path').reply(500, {});
      mockedState.vulnerabilityFeedbackPath = 'create_merge_request_path';

      testAction(
        createMergeRequest,
        null,
        mockedState,
        [],
        [
          {
            type: 'requestCreateMergeRequest',
          },
          {
            type: 'receiveCreateMergeRequestError',
            payload: 'There was an error creating the merge request. Please try again.',
          },
        ],
        done,
      );
    });
  });
});
