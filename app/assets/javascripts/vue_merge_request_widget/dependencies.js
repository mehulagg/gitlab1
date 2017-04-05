// TODO: Add a comment about how this works between EE and CE

export { default as Vue } from 'vue';
export { default as SmartInterval } from '~/smart_interval';
export { default as WidgetHeader } from './components/mr_widget_header';
export { default as WidgetMergeHelp } from './components/mr_widget_merge_help';
export { default as WidgetPipeline } from './components/mr_widget_pipeline';
export { default as WidgetDeployment } from './components/mr_widget_deployment';
export { default as WidgetRelatedLinks } from './components/mr_widget_related_links';
export { default as MergedState } from './components/states/mr_widget_merged';
export { default as FailedToMerge } from './components/states/mr_widget_failed_to_merge';
export { default as ClosedState } from './components/states/mr_widget_closed';
export { default as LockedState } from './components/states/mr_widget_locked';
export { default as WipState } from './components/states/mr_widget_wip';
export { default as ArchivedState } from './components/states/mr_widget_archived';
export { default as ConflictsState } from './components/states/mr_widget_conflicts';
export { default as NothingToMergeState } from './components/states/mr_widget_nothing_to_merge';
export { default as MissingBranchState } from './components/states/mr_widget_missing_branch';
export { default as NotAllowedState } from './components/states/mr_widget_not_allowed';
export { default as UnresolvedDiscussionsState } from './components/states/mr_widget_unresolved_discussions';
export { default as PipelineBlockedState } from './components/states/mr_widget_pipeline_blocked';
export { default as PipelineFailedState } from './components/states/mr_widget_pipeline_failed';
export { default as MergeWhenPipelineSucceedsState } from './components/states/mr_widget_merge_when_pipeline_succeeds';
export { default as CheckingState } from './components/states/mr_widget_checking';
export { default as eventHub } from './event_hub';

/* EE Only */

export { default as StateMaps } from './ee/stores/state_maps';
export { default as ReadyToMergeState } from './ee/components/states/mr_widget_ready_to_merge';
export { default as deviseState } from './ee/stores/devise_state';
export { default as SecondaryGeoNode } from './ee/components/states/mr_widget_secondary_geo_node';
export { default as WidgetApprovals } from './ee/components/approvals/mr_widget_approvals';
export { default as mrWidgetOptions } from './ee/mr_widget_options';
export { default as MRWidgetStore } from './ee/stores/mr_widget_store';
export { default as MRWidgetService } from './ee/services/mr_widget_service';

