import merge from 'lodash/merge';
import { hexToRgba } from './utils';

export const colors = {
  tooltipBackground: '#fff',
  text: '#2e2e2e',
  textSecondary: '#707070',
  textTertiary: '#919191',
  textQuaternary: '#d6d6d6',
  splitLine: '#dfdfdf',
  lines: ['#1F78D1', '#1aaa55', '#fc9403', '#6666c4'],
  threshold: '#db3b21',
};

export const axes = {
  name: 'Value',
  type: 'value',
  nameLocation: 'center',
  nameTextStyle: {
    color: colors.text,
    fontStyle: 'bold',
  },
  axisLabel: {
    color: colors.textTertiary,
  },
  axisLine: {
    lineStyle: { width: 0 },
  },
  axisTick: {
    show: false,
    alignWithLabel: true,
  },
  splitLine: {
    show: true,
    lineStyle: {
      color: colors.splitLine,
    },
  },
};

export const xAxis = merge({}, axes, {
  axisLabel: {
    formatter: name => name,
  },
  boundaryGap: false,
  nameTextStyle: {
    padding: [16, 0, 0, 0],
  },
  splitLine: {
    show: false,
  },
});

export const yAxis = merge({}, axes, {
  nameTextStyle: {
    padding: [0, 0, 32, 0],
  },
});

export const legend = {
  icon: 'path://M0,0H16V4H0Z',
  show: true,
  align: 'left',
  bottom: 0,
  left: 65,
  textStyle: {
    fontWeight: 'bold',
  },
};

export const grid = {
  top: 24,
  bottom: 72,
  left: 70,
  right: 24,
};

/**
 * Meant to be used with Lodash mergeWith
 * Returning undefined will prompt the default merge strategy
 * This function concatenates arrays and uses default merge for everything else
 */
export function additiveArrayMerge(objValue, srcValue) {
  return Array.isArray(objValue) ? objValue.concat(srcValue) : undefined;
}

export function getThresholdConfig(thresholds) {
  const keys = Object.keys(thresholds);
  if (!keys.length) {
    return {};
  }

  const lineData = [];
  const areaData = [];
  keys.forEach(key => {
    const alert = thresholds[key];
    const { threshold } = alert;

    switch (alert.operator) {
      case '>':
      case '&gt;':
        areaData.push([{ xAxis: 'min', yAxis: threshold }, { xAxis: 'max', yAxis: Infinity }]);
        break;

      case '<':
      case '&lt;':
        areaData.push([
          { xAxis: 'min', yAxis: Number.NEGATIVE_INFINITY },
          { xAxis: 'max', yAxis: threshold },
        ]);
        break;

      default:
        break;
    }

    lineData.push([{ xAxis: 'min', yAxis: threshold }, { xAxis: 'max', yAxis: threshold }]);
  });

  return {
    markLine: {
      silent: true,
      symbol: 'none',
      label: {
        show: false,
      },
      lineStyle: {
        color: colors.threshold,
        width: 1,
        type: 'dashed',
      },
      data: lineData,
    },
    markArea: {
      silent: true,
      data: areaData,
      itemStyle: {
        color: hexToRgba(colors.threshold, 0.1),
      },
      zlevel: -1,
    },
  };
}

export default {
  xAxis,
  yAxis,
  legend,
  grid,
  color: colors.lines,
};
