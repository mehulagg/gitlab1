export default () => ({
  // Initial Data
  parentItem: {},
  epicsEndpoint: '',
  issuesEndpoint: '',
  userSignedIn: false,

  children: {},
  childrenFlags: {},
  epicsCount: 0,
  issuesCount: 0,
  descendantCounts: {
    openedEpics: 0,
    closedEpics: 0,
    openedIssues: 0,
    closedIssues: 0,
  },

  // Add Item Form Data
  issuableType: null,
  itemInputValue: '',
  pendingReferences: [],
  itemAutoCompleteSources: {},

  // UI Flags
  itemsFetchInProgress: false,
  itemsFetchFailure: false,
  itemsFetchResultEmpty: false,
  itemAddInProgress: false,
  itemCreateInProgress: false,
  showAddItemForm: false,
  showCreateEpicForm: false,
  autoCompleteEpics: false,
  autoCompleteIssues: false,
  removeItemModalProps: {
    parentItem: {},
    item: {},
  },
});
