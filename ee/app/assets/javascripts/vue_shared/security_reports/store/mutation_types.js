export const SET_HEAD_BLOB_PATH = 'SET_HEAD_BLOB_PATH';
export const SET_BASE_BLOB_PATH = 'SET_BASE_BLOB_PATH';
export const SET_SOURCE_BRANCH = 'SET_SOURCE_BRANCH';
export const SET_VULNERABILITY_FEEDBACK_PATH = 'SET_VULNERABILITY_FEEDBACK_PATH';
export const SET_VULNERABILITY_FEEDBACK_HELP_PATH = 'SET_VULNERABILITY_FEEDBACK_HELP_PATH';
export const SET_CREATE_VULNERABILITY_FEEDBACK_ISSUE_PATH =
  'SET_CREATE_VULNERABILITY_FEEDBACK_ISSUE_PATH';
export const SET_CREATE_VULNERABILITY_FEEDBACK_MERGE_REQUEST_PATH =
  'SET_CREATE_VULNERABILITY_FEEDBACK_MERGE_REQUEST_PATH';
export const SET_CREATE_VULNERABILITY_FEEDBACK_DISMISSAL_PATH =
  'SET_CREATE_VULNERABILITY_FEEDBACK_DISMISSAL_PATH';
export const SET_PIPELINE_ID = 'SET_PIPELINE_ID';
export const SET_CAN_CREATE_ISSUE_PERMISSION = 'SET_CAN_CREATE_ISSUE_PERMISSION';
export const SET_CAN_CREATE_FEEDBACK_PERMISSION = 'SET_CAN_CREATE_FEEDBACK_PERMISSION';

// SAST CONTAINER
export const SET_SAST_CONTAINER_HEAD_PATH = 'SET_SAST_CONTAINER_HEAD_PATH';
export const SET_SAST_CONTAINER_BASE_PATH = 'SET_SAST_CONTAINER_BASE_PATH';
export const REQUEST_SAST_CONTAINER_REPORTS = 'REQUEST_SAST_CONTAINER_REPORTS';
export const RECEIVE_SAST_CONTAINER_REPORTS = 'RECEIVE_SAST_CONTAINER_REPORTS';
export const RECEIVE_SAST_CONTAINER_ERROR = 'RECEIVE_SAST_CONTAINER_ERROR';

// DAST
export const SET_DAST_HEAD_PATH = 'SET_DAST_HEAD_PATH';
export const SET_DAST_BASE_PATH = 'SET_DAST_BASE_PATH';
export const REQUEST_DAST_REPORTS = 'REQUEST_DAST_REPORTS';
export const RECEIVE_DAST_REPORTS = 'RECEIVE_DAST_REPORTS';
export const RECEIVE_DAST_ERROR = 'RECEIVE_DAST_ERROR';

// DEPENDENCY_SCANNING
export const SET_DEPENDENCY_SCANNING_HEAD_PATH = 'SET_DEPENDENCY_SCANNING_HEAD_PATH';
export const SET_DEPENDENCY_SCANNING_BASE_PATH = 'SET_DEPENDENCY_SCANNING_BASE_PATH';
export const REQUEST_DEPENDENCY_SCANNING_REPORTS = 'REQUEST_DEPENDENCY_SCANNING_REPORTS';
export const RECEIVE_DEPENDENCY_SCANNING_REPORTS = 'RECEIVE_DEPENDENCY_SCANNING_REPORTS';
export const RECEIVE_DEPENDENCY_SCANNING_ERROR = 'RECEIVE_DEPENDENCY_SCANNING_ERROR';

// Dismiss security issue
export const SET_ISSUE_MODAL_DATA = 'SET_ISSUE_MODAL_DATA';
export const REQUEST_DISMISS_VULNERABILITY = 'REQUEST_DISMISS_VULNERABILITY';
export const RECEIVE_DISMISS_VULNERABILITY_SUCCESS = 'RECEIVE_DISMISS_VULNERABILITY_SUCCESS';
export const RECEIVE_DISMISS_VULNERABILITY_ERROR = 'RECEIVE_DISMISS_VULNERABILITY_ERROR';
export const REQUEST_ADD_DISMISSAL_COMMENT = 'REQUEST_ADD_DISMISSAL_COMMENT';
export const RECEIVE_ADD_DISMISSAL_COMMENT_SUCCESS = 'RECEIVE_ADD_DISMISSAL_COMMENT_SUCCESS';
export const RECEIVE_ADD_DISMISSAL_COMMENT_ERROR = 'RECEIVE_ADD_DISMISSAL_COMMENT_ERROR';

export const REQUEST_CREATE_ISSUE = 'CREATE_DISMISS_VULNERABILITY';
export const RECEIVE_CREATE_ISSUE_SUCCESS = 'CREATE_DISMISS_VULNERABILITY_SUCCESS';
export const RECEIVE_CREATE_ISSUE_ERROR = 'CREATE_DISMISS_VULNERABILITY_ERROR';

export const REQUEST_CREATE_MERGE_REQUEST = 'REQUEST_CREATE_MERGE_REQUEST';
export const RECEIVE_CREATE_MERGE_REQUEST_SUCCESS = 'RECEIVE_CREATE_MERGE_REQUEST_SUCCESS';
export const RECEIVE_CREATE_MERGE_REQUEST_ERROR = 'RECEIVE_CREATE_MERGE_REQUEST_ERROR';

export const UPDATE_DEPENDENCY_SCANNING_ISSUE = 'UPDATE_DEPENDENCY_SCANNING_ISSUE';
export const UPDATE_CONTAINER_SCANNING_ISSUE = 'UPDATE_CONTAINER_SCANNING_ISSUE';
export const UPDATE_DAST_ISSUE = 'UPDATE_DAST_ISSUE';

export const OPEN_DISMISSAL_COMMENT_BOX = 'OPEN_DISMISSAL_COMMENT_BOX ';
export const CLOSE_DISMISSAL_COMMENT_BOX = 'CLOSE_DISMISSAL_COMMENT_BOX';
