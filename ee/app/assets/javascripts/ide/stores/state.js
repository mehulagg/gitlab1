export default () => ({
  canCommit: false,
  currentProjectId: '',
  currentBranchId: '',
  currentBlobView: 'repo-editor',
  changedFiles: [],
  stagedFiles: [],
  editMode: true,
  endpoints: {},
  isInitialRoot: false,
  lastCommitMsg: '',
  lastCommitPath: '',
  loading: false,
  onTopOfBranch: false,
  openFiles: [],
  selectedFile: null,
  path: '',
  parentTreeUrl: '',
  trees: {},
  projects: {},
  leftPanelCollapsed: false,
  rightPanelCollapsed: false,
  panelResizing: false,
});
