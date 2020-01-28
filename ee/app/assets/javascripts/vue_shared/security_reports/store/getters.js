import { s__, sprintf } from '~/locale';
import { countIssues, groupedTextBuilder } from './utils';
import { LOADING, ERROR, SUCCESS } from './constants';
import messages from './messages';

export const summaryCounts = state =>
  [state.sast, state.containerScanning, state.dast, state.dependencyScanning].reduce(
    (acc, report) => {
      const curr = countIssues(report);
      acc.added += curr.added;
      acc.dismissed += curr.dismissed;
      acc.fixed += curr.fixed;
      acc.existing += curr.existing;
      return acc;
    },
    { added: 0, dismissed: 0, fixed: 0, existing: 0 },
  );

export const groupedSummaryText = (state, getters) => {
  const reportType = s__('ciReport|Security scanning');

  // All reports are loading
  if (getters.areAllReportsLoading) {
    return sprintf(messages.TRANSLATION_IS_LOADING, { reportType });
  }

  // All reports returned error
  if (getters.allReportsHaveError) {
    return s__('ciReport|Security scanning failed loading any results');
  }

  const { added, fixed, existing, dismissed } = getters.summaryCounts;

  let status = '';

  if (getters.areReportsLoading && getters.anyReportHasError) {
    status = s__('ciReport|(is loading, errors when loading results)');
  } else if (getters.areReportsLoading && !getters.anyReportHasError) {
    status = s__('ciReport|(is loading)');
  } else if (!getters.areReportsLoading && getters.anyReportHasError) {
    status = s__('ciReport|(errors when loading results)');
  }

  /*
   In order to correct wording, we ne to set the base property to true,
   if at least one report has a base.
   */
  const paths = { head: true, base: !getters.noBaseInAllReports };

  return groupedTextBuilder({ reportType, paths, added, fixed, existing, dismissed, status });
};

export const summaryStatus = (state, getters) => {
  if (getters.areReportsLoading) {
    return LOADING;
  }

  if (getters.anyReportHasError || getters.anyReportHasIssues) {
    return ERROR;
  }

  return SUCCESS;
};

export const areReportsLoading = state =>
  state.sast.isLoading ||
  state.dast.isLoading ||
  state.containerScanning.isLoading ||
  state.dependencyScanning.isLoading;

export const areAllReportsLoading = state =>
  state.sast.isLoading &&
  state.dast.isLoading &&
  state.containerScanning.isLoading &&
  state.dependencyScanning.isLoading;

export const allReportsHaveError = state =>
  state.sast.hasError &&
  state.dast.hasError &&
  state.containerScanning.hasError &&
  state.dependencyScanning.hasError;

export const anyReportHasError = state =>
  state.sast.hasError ||
  state.dast.hasError ||
  state.containerScanning.hasError ||
  state.dependencyScanning.hasError;

export const noBaseInAllReports = state =>
  !state.sast.hasBaseReport &&
  !state.dast.hasBaseReport &&
  !state.containerScanning.hasBaseReport &&
  !state.dependencyScanning.hasBaseReport;

export const anyReportHasIssues = state =>
  state.sast.newIssues.length > 0 ||
  state.dast.newIssues.length > 0 ||
  state.containerScanning.newIssues.length > 0 ||
  state.dependencyScanning.newIssues.length > 0;

export const isBaseSecurityReportOutOfDate = state =>
  state.sast.baseReportOutofDate ||
  state.dast.baseReportOutofDate ||
  state.containerScanning.baseReportOutofDate ||
  state.dependencyScanning.baseReportOutofDate;

// prevent babel-plugin-rewire from generating an invalid default during karma tests
export default () => {};
