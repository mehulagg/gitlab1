<script>
import { GlTabs, GlTab } from '@gitlab/ui';
import DeploymentFrequencyCharts from 'ee/dora/components/deployment_frequency_charts.vue';
import LeadTimeCharts from 'ee/dora/components/lead_time_charts.vue';
import { mergeUrlParams, updateHistory, getParameterValues } from '~/lib/utils/url_utility';
import ReleaseStatsCard from './release_stats_card.vue';

export default {
  name: 'CiCdAnalyticsApp',
  components: {
    ReleaseStatsCard,
    GlTabs,
    GlTab,
    DeploymentFrequencyCharts,
    LeadTimeCharts,
  },
  inject: {
    shouldRenderDoraCharts: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      selectedTabIndex: 0,
    };
  },
  computed: {
    tabs() {
      const tabsToShow = ['release-statistics'];

      if (this.shouldRenderDoraCharts) {
        tabsToShow.push('deployment-frequency', 'lead-time');
      }

      return tabsToShow;
    },
    releaseStatsCardClasses() {
      return ['gl-mt-5'];
    },
  },
  created() {
    this.selectTab();
    window.addEventListener('popstate', this.selectTab);
  },
  methods: {
    selectTab() {
      const [tabQueryParam] = getParameterValues('tab');
      const tabIndex = this.tabs.indexOf(tabQueryParam);
      this.selectedTabIndex = tabIndex >= 0 ? tabIndex : 0;
    },
    onTabChange(newIndex) {
      if (newIndex !== this.selectedTabIndex) {
        this.selectedTabIndex = newIndex;
        const path = mergeUrlParams({ tab: this.tabs[newIndex] }, window.location.pathname);
        updateHistory({ url: path, title: window.title });
      }
    },
  },
};
</script>
<template>
  <div>
    <gl-tabs v-if="tabs.length > 1" :value="selectedTabIndex" @input="onTabChange">
      <gl-tab :title="s__('CICDAnalytics|Release statistics')">
        <release-stats-card :class="releaseStatsCardClasses" />
      </gl-tab>
      <template v-if="shouldRenderDoraCharts">
        <gl-tab :title="s__('CICDAnalytics|Deployment frequency')">
          <deployment-frequency-charts />
        </gl-tab>
        <gl-tab :title="s__('CICDAnalytics|Lead time')">
          <lead-time-charts />
        </gl-tab>
      </template>
    </gl-tabs>
    <release-stats-card v-else :class="releaseStatsCardClasses" />
  </div>
</template>
