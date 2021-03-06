<script>
import { GlButton, GlForm, GlFormGroup } from '@gitlab/ui';
import { mapActions, mapState } from 'vuex';
import { mapComputed } from '~/vuex_shared/bindings';
import { APPROVAL_SETTINGS_I18N } from '../constants';
import ApprovalSettingsCheckbox from './approval_settings_checkbox.vue';

export default {
  components: {
    ApprovalSettingsCheckbox,
    GlButton,
    GlForm,
    GlFormGroup,
  },
  props: {
    approvalSettingsPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      hasFormLoaded: false,
    };
  },
  computed: {
    ...mapState({
      isLoading: (state) => state.approvals.isLoading,
    }),
    ...mapComputed(
      [
        { key: 'preventAuthorApproval', updateFn: 'setPreventAuthorApproval' },
        { key: 'preventCommittersApproval', updateFn: 'setPreventCommittersApproval' },
        { key: 'preventMrApprovalRuleEdit', updateFn: 'setPreventMrApprovalRuleEdit' },
        { key: 'removeApprovalsOnPush', updateFn: 'setRemoveApprovalsOnPush' },
        { key: 'requireUserPassword', updateFn: 'setRequireUserPassword' },
      ],
      undefined,
      (state) => state.approvals.settings,
    ),
  },
  async created() {
    await this.fetchSettings(this.approvalSettingsPath);
    this.hasFormLoaded = true;
  },
  methods: {
    ...mapActions(['fetchSettings', 'updateSettings']),
    onSubmit() {
      this.updateSettings(this.approvalSettingsPath);
    },
  },
  links: {
    preventAuthorApprovalDocsAnchor:
      'allowing-merge-request-authors-to-approve-their-own-merge-requests',
    preventMrApprovalRuleEditDocsAnchor: 'editing--overriding-approval-rules-per-merge-request',
    requireUserPasswordDocsAnchor: 'require-authentication-when-approving-a-merge-request',
    removeApprovalsOnPushDocsAnchor: 'resetting-approvals-on-push',
    preventCommittersApprovalAnchor: 'prevent-approval-of-merge-requests-by-their-committers',
  },
  i18n: APPROVAL_SETTINGS_I18N,
};
</script>

<template>
  <gl-form v-if="hasFormLoaded" @submit.prevent="onSubmit">
    <gl-form-group>
      <approval-settings-checkbox
        v-model="preventAuthorApproval"
        :label="$options.i18n.authorApprovalLabel"
        :anchor="$options.links.preventAuthorApprovalDocsAnchor"
        data-testid="prevent-author-approval"
      />
      <approval-settings-checkbox
        v-model="preventMrApprovalRuleEdit"
        :label="$options.i18n.preventMrApprovalRuleEditLabel"
        :anchor="$options.links.preventMrApprovalRuleEditDocsAnchor"
        data-testid="prevent-mr-approval-rule-edit"
      />
      <approval-settings-checkbox
        v-model="requireUserPassword"
        :label="$options.i18n.requireUserPasswordLabel"
        :anchor="$options.links.requireUserPasswordDocsAnchor"
        data-testid="require-user-password"
      />
      <approval-settings-checkbox
        v-model="removeApprovalsOnPush"
        :label="$options.i18n.removeApprovalsOnPushLabel"
        :anchor="$options.links.removeApprovalsOnPushDocsAnchor"
        data-testid="remove-approvals-on-push"
      />
      <approval-settings-checkbox
        v-model="preventCommittersApproval"
        :label="$options.i18n.preventCommittersApprovalLabel"
        :anchor="$options.links.preventCommittersApprovalAnchor"
        data-testid="prevent-committers-approval"
      />
    </gl-form-group>
    <gl-button type="submit" variant="success" category="primary" :disabled="isLoading">
      {{ $options.i18n.saveChanges }}
    </gl-button>
  </gl-form>
</template>
