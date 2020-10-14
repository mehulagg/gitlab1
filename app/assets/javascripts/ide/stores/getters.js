import { filePathMatches } from './utils';
import {
  leftSidebarViews,
  packageJsonPath,
  PERMISSION_READ_MR,
  PERMISSION_CREATE_MR,
  PERMISSION_PUSH_CODE,
} from '../constants';
import { addNumericSuffix } from '~/ide/utils';
import Api from '~/api';

export const isFileActive = state => file => file.id === state.activeFile?.id;

export const addedFiles = state => state.changedFiles.filter(f => f.tempFile);

export const modifiedFiles = state => state.changedFiles.filter(f => !f.tempFile);

export const projectsWithTrees = state =>
  Object.keys(state.projects).map(projectId => {
    const project = state.projects[projectId];

    return {
      ...project,
      branches: Object.keys(project.branches).map(branchId => {
        const branch = project.branches[branchId];

        return {
          ...branch,
          tree: state.trees[branch.treeId],
        };
      }),
    };
  });

export const currentMergeRequest = state => {
  if (
    state.projects[state.currentProjectId] &&
    state.projects[state.currentProjectId].mergeRequests
  ) {
    return state.projects[state.currentProjectId].mergeRequests[state.currentMergeRequestId];
  }
  return null;
};

export const findProject = state => projectId => state.projects[projectId];

export const currentProject = (state, getters) => getters.findProject(state.currentProjectId);

export const emptyRepo = state =>
  state.projects[state.currentProjectId] && state.projects[state.currentProjectId].empty_repo;

export const currentTree = state =>
  state.trees[`${state.currentProjectId}/${state.currentBranchId}`];

export const hasMergeRequest = state => Boolean(state.currentMergeRequestId);

export const allBlobs = state =>
  Object.keys(state.entries)
    .reduce((acc, key) => {
      const entry = state.entries[key];

      if (entry.type === 'blob') {
        acc.push(entry);
      }

      return acc;
    }, [])
    .sort((a, b) => b.lastOpenedAt - a.lastOpenedAt);

export const getChangedFile = state => path => state.changedFiles.find(f => f.path === path);
export const getOpenFile = state => path => state.openFiles.find(f => f.path === path);

export const lastOpenedFile = state =>
  state.changedFiles.sort((a, b) => b.lastOpenedAt - a.lastOpenedAt)[0];

export const isEditModeActive = state => state.currentActivityView === leftSidebarViews.edit.name;
export const isCommitModeActive = state =>
  state.currentActivityView === leftSidebarViews.commit.name;
export const isReviewModeActive = state =>
  state.currentActivityView === leftSidebarViews.review.name;

export const someUncommittedChanges = state => Boolean(state.changedFiles.length);

export const getChangesInFolder = state => path =>
  state.changedFiles.filter(f => filePathMatches(f.path, path)).length;

export const lastCommit = (state, getters) => {
  const branch = getters.currentProject && getters.currentBranch;

  return branch ? branch.commit : null;
};

export const findBranch = (state, getters) => (projectId, branchId) => {
  const project = getters.findProject(projectId);

  return project && project.branches[branchId];
};

export const currentBranch = (state, getters) =>
  getters.findBranch(state.currentProjectId, state.currentBranchId);

export const branchName = (_state, getters) => getters.currentBranch && getters.currentBranch.name;

export const packageJson = state => state.entries[packageJsonPath];

export const isOnDefaultBranch = (_state, getters) =>
  getters.currentProject && getters.currentProject.default_branch === getters.branchName;

export const canPushToBranch = (_state, getters) => {
  return Boolean(getters.currentBranch ? getters.currentBranch.can_push : getters.canPushCode);
};

export const findProjectPermissions = (state, getters) => projectId =>
  getters.findProject(projectId)?.userPermissions || {};

export const canReadMergeRequests = (state, getters) =>
  Boolean(getters.findProjectPermissions(state.currentProjectId)[PERMISSION_READ_MR]);

export const canCreateMergeRequests = (state, getters) =>
  Boolean(getters.findProjectPermissions(state.currentProjectId)[PERMISSION_CREATE_MR]);

export const canPushCode = (state, getters) =>
  Boolean(getters.findProjectPermissions(state.currentProjectId)[PERMISSION_PUSH_CODE]);

export const entryExists = state => path =>
  Boolean(state.entries[path] && !state.entries[path].deleted);

export const getAvailableFileName = (state, getters) => path => {
  let newPath = path;

  while (getters.entryExists(newPath)) {
    newPath = addNumericSuffix(newPath);
  }

  return newPath;
};

export const getUrlForPath = state => path =>
  `/project/${state.currentProjectId}/tree/${state.currentBranchId}/-/${path}/`;

export const getJsonSchemaForPath = (state, getters) => path => {
  const [namespace, ...project] = state.currentProjectId.split('/');
  return {
    uri:
      // eslint-disable-next-line no-restricted-globals
      location.origin +
      Api.buildUrl(Api.projectFileSchemaPath)
        .replace(':namespace_path', namespace)
        .replace(':project_path', project.join('/'))
        .replace(':ref', getters.currentBranch?.commit.id || state.currentBranchId)
        .replace(':filename', path),
    fileMatch: [`*${path}`],
  };
};
