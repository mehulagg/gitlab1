import dateFormat from 'dateformat';
import { isNumber } from 'lodash';
import httpStatus from '~/lib/utils/http_status';
import { dateFormats } from '../../shared/constants';
import { transformStagesForPathNavigation } from '../utils';
import { DEFAULT_VALUE_STREAM_ID } from '../constants';

export const hasNoAccessError = state => state.errorCode === httpStatus.FORBIDDEN;

export const currentValueStreamId = ({ selectedValueStream }) =>
  selectedValueStream?.id || DEFAULT_VALUE_STREAM_ID;

export const currentGroupPath = ({ selectedGroup }) =>
  selectedGroup && selectedGroup.fullPath ? selectedGroup.fullPath : null;

export const currentGroupParentPath = ({ selectedGroup }, getters) =>
  selectedGroup?.parentId || getters.currentGroupPath;

export const selectedProjectIds = ({ selectedProjects }) =>
  selectedProjects.length ? selectedProjects.map(({ id }) => id) : [];

export const cycleAnalyticsRequestParams = (
  {
    startDate = null,
    endDate = null,
    selectedAuthor = null,
    selectedMilestone = null,
    selectedAssignees = [],
    selectedLabels = [],
  },
  getters,
) => ({
  project_ids: getters.selectedProjectIds,
  created_after: startDate ? dateFormat(startDate, dateFormats.isoDate) : null,
  created_before: endDate ? dateFormat(endDate, dateFormats.isoDate) : null,
  author_username: selectedAuthor,
  milestone_title: selectedMilestone,
  assignee_username: selectedAssignees,
  label_name: selectedLabels,
});

const filterStagesByHiddenStatus = (stages = [], isHidden = true) =>
  stages.filter(({ hidden = false }) => hidden === isHidden);

export const hiddenStages = ({ stages }) => filterStagesByHiddenStatus(stages);
export const activeStages = ({ stages }) => filterStagesByHiddenStatus(stages, false);

export const enableCustomOrdering = ({ stages, errorSavingStageOrder }) =>
  stages.some(stage => isNumber(stage.id)) && !errorSavingStageOrder;

export const customStageFormActive = ({ isCreatingCustomStage, isEditingCustomStage }) =>
  Boolean(isCreatingCustomStage || isEditingCustomStage);

/**
 * Until there are controls in place to edit stages outside of the stage table,
 * the path navigation component will only display active stages.
 *
 * https://gitlab.com/gitlab-org/gitlab/-/issues/216227
 */
export const pathNavigationData = ({ stages, medians, selectedStage }) =>
  transformStagesForPathNavigation({
    stages: filterStagesByHiddenStatus(stages, false),
    medians,
    selectedStage,
  });
