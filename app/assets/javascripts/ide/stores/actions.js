import $ from 'jquery';
import Vue from 'vue';
import { visitUrl } from '~/lib/utils/url_utility';
import flash from '~/flash';
import * as types from './mutation_types';
import FilesDecoratorWorker from './workers/files_decorator_worker';

export const redirectToUrl = (_, url) => visitUrl(url);

export const setInitialData = ({ commit }, data) => commit(types.SET_INITIAL_DATA, data);

export const discardAllChanges = ({ state, commit, dispatch }) => {
  state.changedFiles.forEach(file => {
    commit(types.DISCARD_FILE_CHANGES, file.path);

    if (file.tempFile) {
      dispatch('closeFile', file.path);
    }
  });

  commit(types.REMOVE_ALL_CHANGES_FILES);
};

export const closeAllFiles = ({ state, dispatch }) => {
  state.openFiles.forEach(file => dispatch('closeFile', file));
};

export const setPanelCollapsedStatus = ({ commit }, { side, collapsed }) => {
  if (side === 'left') {
    commit(types.SET_LEFT_PANEL_COLLAPSED, collapsed);
  } else {
    commit(types.SET_RIGHT_PANEL_COLLAPSED, collapsed);
  }
};

export const toggleRightPanelCollapsed = ({ dispatch, state }, e = undefined) => {
  if (e) {
    $(e.currentTarget)
      .tooltip('hide')
      .blur();
  }

  dispatch('setPanelCollapsedStatus', {
    side: 'right',
    collapsed: !state.rightPanelCollapsed,
  });
};

export const setResizingStatus = ({ commit }, resizing) => {
  commit(types.SET_RESIZING_STATUS, resizing);
};

export const createTempEntry = (
  { state, commit, dispatch },
  { name, type, content = '', base64 = false },
) =>
  new Promise(resolve => {
    const worker = new FilesDecoratorWorker();
    const fullName = name.slice(-1) !== '/' && type === 'tree' ? `${name}/` : name;

    if (state.entries[name]) {
      flash(
        `The name "${name.split('/').pop()}" is already taken in this directory.`,
        'alert',
        document,
        null,
        false,
        true,
      );

      resolve();

      return null;
    }

    worker.addEventListener('message', ({ data }) => {
      const { file, parentPath } = data;

      worker.terminate();

      commit(types.CREATE_TMP_ENTRY, {
        data,
        projectId: state.currentProjectId,
        branchId: state.currentBranchId,
      });

      if (type === 'blob') {
        commit(types.TOGGLE_FILE_OPEN, file.path);
        commit(types.ADD_FILE_TO_CHANGED, file.path);
        dispatch('setFileActive', file.path);
      }

      if (parentPath && !state.entries[parentPath].opened) {
        commit(types.TOGGLE_TREE_OPEN, parentPath);
      }

      resolve(file);
    });

    worker.postMessage({
      data: [fullName],
      projectId: state.currentProjectId,
      branchId: state.currentBranchId,
      type,
      tempFile: true,
      base64,
      content,
    });

    return null;
  });

export const scrollToTab = () => {
  Vue.nextTick(() => {
    const tabs = document.getElementById('tabs');

    if (tabs) {
      const tabEl = tabs.querySelector('.active .repo-tab');

      tabEl.focus();
    }
  });
};

export const stageAllChanges = ({ state, commit }) => {
  commit(types.SET_LAST_COMMIT_MSG, '');

  state.changedFiles.forEach(file => commit(types.STAGE_CHANGE, file.path));
};

export const unstageAllChanges = ({ state, commit }) => {
  state.stagedFiles.forEach(file => commit(types.UNSTAGE_CHANGE, file.path));
};

export const updateViewer = ({ commit }, viewer) => {
  commit(types.UPDATE_VIEWER, viewer);
};

export const updateDelayViewerUpdated = ({ commit }, delay) => {
  commit(types.UPDATE_DELAY_VIEWER_CHANGE, delay);
};

export const updateActivityBarView = ({ commit }, view) => {
  commit(types.UPDATE_ACTIVITY_BAR_VIEW, view);
};

export const setEmptyStateSvgs = ({ commit }, svgs) => {
  commit(types.SET_EMPTY_STATE_SVGS, svgs);
};

export const setCurrentBranchId = ({ commit }, currentBranchId) => {
  commit(types.SET_CURRENT_BRANCH, currentBranchId);
};

export const updateTempFlagForEntry = ({ commit, dispatch, state }, { file, tempFile }) => {
  commit(types.UPDATE_TEMP_FLAG, { path: file.path, tempFile });

  if (file.parentPath) {
    dispatch('updateTempFlagForEntry', { file: state.entries[file.parentPath], tempFile });
  }
};

export const toggleFileFinder = ({ commit }, fileFindVisible) =>
  commit(types.TOGGLE_FILE_FINDER, fileFindVisible);

export const burstUnusedSeal = ({ state, commit }) => {
  if (state.unusedSeal) {
    commit(types.BURST_UNUSED_SEAL);
  }
};

export const setRightPane = ({ commit }, view) => {
  commit(types.SET_RIGHT_PANE, view);
};

export const setLinks = ({ commit }, links) => commit(types.SET_LINKS, links);

export const setErrorMessage = ({ commit }, errorMessage) =>
  commit(types.SET_ERROR_MESSAGE, errorMessage);

export const openNewEntryModal = ({ commit }, { type, path = '' }) => {
  commit(types.OPEN_NEW_ENTRY_MODAL, { type, path });

  // open the modal manually so we don't mess around with dropdown/rows
  $('#ide-new-entry').modal('show');
};

export const deleteEntry = ({ commit, dispatch, state }, path) => {
  dispatch('burstUnusedSeal');
  dispatch('closeFile', state.entries[path]);
  commit(types.DELETE_ENTRY, path);
};

export const resetOpenFiles = ({ commit }) => commit(types.RESET_OPEN_FILES);

export * from './actions/tree';
export * from './actions/file';
export * from './actions/project';
export * from './actions/merge_request';

// prevent babel-plugin-rewire from generating an invalid default during karma tests
export default () => {};
