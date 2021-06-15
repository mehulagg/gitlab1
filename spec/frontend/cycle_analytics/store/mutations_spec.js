import * as types from '~/cycle_analytics/store/mutation_types';
import mutations from '~/cycle_analytics/store/mutations';
import {
  selectedStage,
  rawEvents,
  convertedEvents,
  rawData,
  convertedData,
  selectedValueStream,
  rawValueStreamStages,
  valueStreamStages,
} from '../mock_data';

let state;
const mockRequestPath = 'fake/request/path';
const mockStartData = '2021-04-20';

describe('Project Value Stream Analytics mutations', () => {
  beforeEach(() => {
    state = {};
  });

  afterEach(() => {
    state = null;
  });

  it.each`
    mutation                                      | stateKey                 | value
    ${types.REQUEST_VALUE_STREAMS}                | ${'valueStreams'}        | ${[]}
    ${types.RECEIVE_VALUE_STREAMS_ERROR}          | ${'valueStreams'}        | ${[]}
    ${types.REQUEST_VALUE_STREAM_STAGES}          | ${'stages'}              | ${[]}
    ${types.RECEIVE_VALUE_STREAM_STAGES_ERROR}    | ${'stages'}              | ${[]}
    ${types.REQUEST_CYCLE_ANALYTICS_DATA}         | ${'isLoading'}           | ${true}
    ${types.REQUEST_CYCLE_ANALYTICS_DATA}         | ${'hasError'}            | ${false}
    ${types.RECEIVE_CYCLE_ANALYTICS_DATA_SUCCESS} | ${'hasError'}            | ${false}
    ${types.RECEIVE_CYCLE_ANALYTICS_DATA_ERROR}   | ${'isLoading'}           | ${false}
    ${types.RECEIVE_CYCLE_ANALYTICS_DATA_ERROR}   | ${'hasError'}            | ${true}
    ${types.REQUEST_STAGE_DATA}                   | ${'isLoadingStage'}      | ${true}
    ${types.REQUEST_STAGE_DATA}                   | ${'isEmptyStage'}        | ${false}
    ${types.REQUEST_STAGE_DATA}                   | ${'hasError'}            | ${false}
    ${types.REQUEST_STAGE_DATA}                   | ${'selectedStageEvents'} | ${[]}
    ${types.RECEIVE_STAGE_DATA_SUCCESS}           | ${'isLoadingStage'}      | ${false}
    ${types.RECEIVE_STAGE_DATA_SUCCESS}           | ${'selectedStageEvents'} | ${[]}
    ${types.RECEIVE_STAGE_DATA_SUCCESS}           | ${'hasError'}            | ${false}
    ${types.RECEIVE_STAGE_DATA_ERROR}             | ${'isLoadingStage'}      | ${false}
    ${types.RECEIVE_STAGE_DATA_ERROR}             | ${'selectedStageEvents'} | ${[]}
    ${types.RECEIVE_STAGE_DATA_ERROR}             | ${'hasError'}            | ${true}
    ${types.RECEIVE_STAGE_DATA_ERROR}             | ${'isEmptyStage'}        | ${true}
  `('$mutation will set $stateKey to $value', ({ mutation, stateKey, value }) => {
    mutations[mutation](state, {});

    expect(state).toMatchObject({ [stateKey]: value });
  });

  it.each`
    mutation                                      | payload                             | stateKey                 | value
    ${types.INITIALIZE_VSA}                       | ${{ requestPath: mockRequestPath }} | ${'requestPath'}         | ${mockRequestPath}
    ${types.SET_DATE_RANGE}                       | ${{ startDate: mockStartData }}     | ${'startDate'}           | ${mockStartData}
    ${types.SET_LOADING}                          | ${true}                             | ${'isLoading'}           | ${true}
    ${types.SET_LOADING}                          | ${false}                            | ${'isLoading'}           | ${false}
    ${types.SET_SELECTED_VALUE_STREAM}            | ${selectedValueStream}              | ${'selectedValueStream'} | ${selectedValueStream}
    ${types.RECEIVE_CYCLE_ANALYTICS_DATA_SUCCESS} | ${rawData}                          | ${'summary'}             | ${convertedData.summary}
    ${types.RECEIVE_VALUE_STREAMS_SUCCESS}        | ${[selectedValueStream]}            | ${'valueStreams'}        | ${[selectedValueStream]}
    ${types.RECEIVE_VALUE_STREAM_STAGES_SUCCESS}  | ${{ stages: rawValueStreamStages }} | ${'stages'}              | ${valueStreamStages}
  `(
    '$mutation with $payload will set $stateKey to $value',
    ({ mutation, payload, stateKey, value }) => {
      mutations[mutation](state, payload);

      expect(state).toMatchObject({ [stateKey]: value });
    },
  );

  describe('with a stage selected', () => {
    beforeEach(() => {
      state = {
        selectedStage,
      };
    });

    it.each`
      mutation                            | payload                  | stateKey                 | value
      ${types.RECEIVE_STAGE_DATA_SUCCESS} | ${{ events: [] }}        | ${'isEmptyStage'}        | ${true}
      ${types.RECEIVE_STAGE_DATA_SUCCESS} | ${{ events: rawEvents }} | ${'selectedStageEvents'} | ${convertedEvents}
      ${types.RECEIVE_STAGE_DATA_SUCCESS} | ${{ events: rawEvents }} | ${'isEmptyStage'}        | ${false}
    `(
      '$mutation with $payload will set $stateKey to $value',
      ({ mutation, payload, stateKey, value }) => {
        mutations[mutation](state, payload);

        expect(state).toMatchObject({ [stateKey]: value });
      },
    );
  });
});
