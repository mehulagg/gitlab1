<script>
import { GlLink } from '@gitlab/ui';
import { mapActions } from 'vuex';

import { LICENSE_MANAGEMENT } from 'ee/vue_shared/license_compliance/store/constants';
import LicensePackages from './license_packages.vue';

export default {
  name: 'LicenseIssueBody',
  components: { LicensePackages, GlLink },
  props: {
    issue: {
      type: Object,
      required: true,
    },
  },
  computed: {
    hasPackages() {
      return Boolean(this.issue.packages.length);
    },
  },
  methods: { ...mapActions(LICENSE_MANAGEMENT, ['setLicenseInModal']) },
};
</script>

<template>
  <div class="report-block-info license-item">
    <gl-link v-if="issue.url" :href="issue.url" target="_blank">{{ issue.name }}</gl-link>
    <span v-else data-testid="license-copy">{{ issue.name }}</span>
    <license-packages v-if="hasPackages" :packages="issue.packages" class="text-secondary" />
  </div>
</template>
