import _ from 'underscore';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';

function sortMetrics(metrics) {
  return _.chain(metrics)
    .sortBy('title')
    .sortBy('weight')
    .value();
}

function checkQueryEmptyData(query) {
  return {
    ...query,
    result: query.result.filter(timeSeries => {
      const newTimeSeries = timeSeries;
      const hasValue = series =>
        !Number.isNaN(series[1]) && (series[1] !== null || series[1] !== undefined);
      const hasNonNullValue = timeSeries.values.find(hasValue);

      newTimeSeries.values = hasNonNullValue ? newTimeSeries.values : [];

      return newTimeSeries.values.length > 0;
    }),
  };
}

function removeTimeSeriesNoData(queries) {
  return queries.reduce((series, query) => series.concat(checkQueryEmptyData(query)), []);
}

// Metrics and queries are currently stored 1:1, so `queries` is an array of length one.
// We want to group queries onto a single chart by title & y-axis label.
// This function will no longer be required when metrics:queries are 1:many,
// though there is no consequence if the function stays in use.
// @param metrics [Array<Object>]
//      Ex) [
//            { id: 1, title: 'title', y_label: 'MB', queries: [{ ...query1Attrs }] },
//            { id: 2, title: 'title', y_label: 'MB', queries: [{ ...query2Attrs }] },
//            { id: 3, title: 'new title', y_label: 'MB', queries: [{ ...query3Attrs }] }
//          ]
// @return [Array<Object>]
//      Ex) [
//            { title: 'title', y_label: 'MB', queries: [{ metricId: 1, ...query1Attrs },
//                                                       { metricId: 2, ...query2Attrs }] },
//            { title: 'new title', y_label: 'MB', queries: [{ metricId: 3, ...query3Attrs }]}
//          ]
function groupQueriesByChartInfo(metrics) {
  const metricsByChart = metrics.reduce((accumulator, metric) => {
    const { queries, ...chart } = metric;
    const metricId = chart.id ? chart.id.toString() : null;

    const chartKey = `${chart.title}|${chart.y_label}`;
    accumulator[chartKey] = accumulator[chartKey] || { ...chart, queries: [] };

    queries.forEach(queryAttrs => accumulator[chartKey].queries.push({ metricId, ...queryAttrs }));

    return accumulator;
  }, {});

  return Object.values(metricsByChart);
}

export default class MonitoringStore {
  constructor() {
    this.groups = [];
    this.deploymentData = [];
    this.environmentsData = [];

    this.panelGroups = [];
  }

  storeMetrics(groups = []) {
    this.groups = groups.map(group => ({
      ...group,
      metrics: normalizeMetrics(sortMetrics(group.metrics)),
    }));
  }

  storeDashboard(dashboard = {}) {
    // this.groups = convertObjectPropsToCamelCase(dashboard.panelGroups, { deep: true });
    // console.log(dashboard.panelGroups)
    // return;
    const groups = dashboard.panelGroups;

    this.groups = groups.reduce((acc, group) => {
      const panelsWithResults = group.panels.filter(panel => {
        return panel.queries[0].result;
      });

      if (panelsWithResults.length === 0) {
        return acc;
      }

      const metrics = normalizeMetrics(sortMetrics(panelsWithResults));

      return acc.concat({
        ...group,
        metrics,
      });
    }, []);
  }

  storeDashboardMetrics(metrics) {
    console.log('metrics)');
    console.log(metrics);
  }

  storeDeploymentData(deploymentData = []) {
    this.deploymentData = deploymentData;
  }

  storeEnvironmentsData(environmentsData = []) {
    this.environmentsData = environmentsData.filter(environment => !!environment.last_deployment);
  }

  getMetricsCount() {
    return this.groups.reduce((count, group) => count + group.metrics.length, 0);
  }
}
