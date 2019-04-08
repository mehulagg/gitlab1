import initIssuesList from '~/issues';
import projectSelect from '~/project_select';
import initFilteredSearch from '~/pages/search/init_filtered_search';
import IssuableFilteredSearchTokenKeys from '~/filtered_search/issuable_filtered_search_token_keys';
import { FILTERED_SEARCH } from '~/pages/constants';

document.addEventListener('DOMContentLoaded', () => {
  if (gon.features.issuesVueComponent) {
    initIssuesList();
  } else {
    initFilteredSearch({
      page: FILTERED_SEARCH.ISSUES,
      filteredSearchTokenKeys: IssuableFilteredSearchTokenKeys,
    });

    projectSelect();
  }
});
