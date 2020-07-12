import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import { TEST_HOST } from 'spec/test_constants';
import testAction from 'helpers/vuex_action_helper';

import createState from 'ee/security_dashboard/store/modules/pipeline_jobs/state';
import * as types from 'ee/security_dashboard/store/modules/pipeline_jobs/mutation_types';
import * as actions from 'ee/security_dashboard/store/modules/pipeline_jobs/actions';

describe('pipeling jobs actions', () => {
  let state;

  beforeEach(() => {
    state = createState();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('setPipelineJobsPath', () => {
    const pipslineJobsPath = 123;

    it('should commit the SET_PIPELINE_JOBS_PATH mutation', done => {
      testAction(
        actions.setPipelineJobsPath,
        pipslineJobsPath,
        state,
        [
          {
            type: types.SET_PIPELINE_JOBS_PATH,
            payload: pipslineJobsPath,
          },
        ],
        [],
        done,
      );
    });
  });

  describe('setProjectId', () => {
    const projectId = 123;

    it('should commit the SET_PIPELINE_JOBS_PATH mutation', done => {
      testAction(
        actions.setProjectId,
        projectId,
        state,
        [
          {
            type: types.SET_PROJECT_ID,
            payload: projectId,
          },
        ],
        [],
        done,
      );
    });
  });

  describe('fetchPipelineJobs', () => {
    let mock;
    const jobs = [{}, {}];

    beforeEach(() => {
      state.pipelineJobsPath = `${TEST_HOST}/pipelines/jobs.json`;
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    describe('on success', () => {
      beforeEach(() => {
        mock.onGet(state.pipelineJobsPath).replyOnce(200, jobs);
      });

      it('should commit the request and success mutations', done => {
        testAction(
          actions.fetchPipelineJobs,
          {},
          state,
          [
            { type: types.REQUEST_PIPELINE_JOBS },
            {
              type: types.RECEIVE_PIPELINE_JOBS_SUCCESS,
              payload: jobs,
            },
          ],
          [],
          done,
        );
      });
    });

    describe('without pipelineJobsPath set', () => {
      beforeEach(() => {
        mock.onGet(state.pipelineJobsPath).replyOnce(200, jobs);
      });

      it('should commit RECEIVE_PIPELINE_JOBS_ERROR mutation', done => {
        state.pipelineJobsPath = '';

        testAction(
          actions.fetchPipelineJobs,
          {},
          state,
          [
            {
              type: types.RECEIVE_PIPELINE_JOBS_ERROR,
              payload: new Error('pipelineJobsPath not defined'),
            },
          ],
          [],
          done,
        );
      });
    });

    describe('without server error', () => {
      beforeEach(() => {
        mock.onGet(state.pipelineJobsPath).replyOnce(404);
      });

      it('should commit REQUEST_PIPELINE_JOBS and RECEIVE_PIPELINE_JOBS_ERROR mutation', done => {
        testAction(
          actions.fetchPipelineJobs,
          {},
          state,
          [
            { type: types.REQUEST_PIPELINE_JOBS },
            {
              type: types.RECEIVE_PIPELINE_JOBS_ERROR,
              payload: new Error('Request failed with status code 404'),
            },
          ],
          [],
          done,
        );
      });
    });
  });
});
