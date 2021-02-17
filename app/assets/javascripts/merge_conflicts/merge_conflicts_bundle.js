// This is a true violation of @gitlab/no-runtime-template-compiler, as it
// relies on app/views/projects/merge_requests/conflicts/show.html.haml for its
// template.
/* eslint-disable @gitlab/no-runtime-template-compiler */
import $ from 'jquery';
import Vue from 'vue';
import { __ } from '~/locale';
import FileIcon from '~/vue_shared/components/file_icon.vue';
import { deprecatedCreateFlash as createFlash } from '../flash';
import initIssuableSidebar from '../init_issuable_sidebar';
import './merge_conflict_store';
import syntaxHighlight from '../syntax_highlight';
import DiffFileEditor from './components/diff_file_editor.vue';
import InlineConflictLines from './components/inline_conflict_lines.vue';
import ParallelConflictLines from './components/parallel_conflict_lines.vue';
import MergeConflictsResolverApp from './merge_conflict_resolver_app.vue';
import MergeConflictsService from './merge_conflict_service';

export default function initMergeConflicts() {
  const INTERACTIVE_RESOLVE_MODE = 'interactive';
  const conflictsEl = document.querySelector('#conflicts');
  const { mergeConflictsStore } = gl.mergeConflicts;
  const mergeConflictsService = new MergeConflictsService({
    conflictsPath: conflictsEl.dataset.conflictsPath,
    resolveConflictsPath: conflictsEl.dataset.resolveConflictsPath,
  });

  initIssuableSidebar();

  gl.MergeConflictsResolverApp = new Vue({
    el: '#conflicts',
    components: {
      FileIcon,
      DiffFileEditor,
      InlineConflictLines,
      ParallelConflictLines,
      MergeConflictsResolverApp,
    },
    data: mergeConflictsStore.state,
    computed: {
      conflictsCountText() {
        return mergeConflictsStore.getConflictsCountText();
      },
      readyToCommit() {
        return mergeConflictsStore.isReadyToCommit();
      },
      commitButtonText() {
        return mergeConflictsStore.getCommitButtonText();
      },
      showDiffViewTypeSwitcher() {
        return mergeConflictsStore.fileTextTypePresent();
      },
    },
    created() {
      mergeConflictsService
        .fetchConflictsData()
        .then(({ data }) => {
          if (data.type === 'error') {
            mergeConflictsStore.setFailedRequest(data.message);
          } else {
            mergeConflictsStore.setConflictsData(data);
          }

          mergeConflictsStore.setLoadingState(false);

          this.$nextTick(() => {
            syntaxHighlight($('.js-syntax-highlight'));
          });
        })
        .catch(() => {
          mergeConflictsStore.setLoadingState(false);
          mergeConflictsStore.setFailedRequest();
        });
    },
    methods: {
      handleViewTypeChange(viewType) {
        mergeConflictsStore.setViewType(viewType);
      },
      onClickResolveModeButton(file, mode) {
        if (mode === INTERACTIVE_RESOLVE_MODE && file.resolveEditChanged) {
          mergeConflictsStore.setPromptConfirmationState(file, true);
          return;
        }

        mergeConflictsStore.setFileResolveMode(file, mode);
      },
      acceptDiscardConfirmation(file) {
        mergeConflictsStore.setPromptConfirmationState(file, false);
        mergeConflictsStore.setFileResolveMode(file, INTERACTIVE_RESOLVE_MODE);
      },
      cancelDiscardConfirmation(file) {
        mergeConflictsStore.setPromptConfirmationState(file, false);
      },
      commit() {
        mergeConflictsStore.setSubmitState(true);

        mergeConflictsService
          .submitResolveConflicts(mergeConflictsStore.getCommitData())
          .then(({ data }) => {
            window.location.href = data.redirect_to;
          })
          .catch(() => {
            mergeConflictsStore.setSubmitState(false);
            createFlash(__('Failed to save merge conflicts resolutions. Please try again!'));
          });
      },
    },
  });
}
