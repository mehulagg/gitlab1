import FilteredSearchManager from 'ee/filtered_search/filtered_search_manager';
import IssuableFilteredSearchTokenKeys from 'ee/filtered_search/issuable_filtered_search_token_keys';
import FilteredSearchSpecHelper from 'helpers/filtered_search_spec_helper';
import FilteredSearchDropdownManager from '~/filtered_search/filtered_search_dropdown_manager';
import { FILTERED_SEARCH } from '~/pages/constants';

const TEST_EPICS_ENDPOINT = '/test/epics/endpoint';

describe('Filtered Search Manager (EE)', () => {
  let manager;

  const createSubject = () => {
    manager = new FilteredSearchManager({
      page: FILTERED_SEARCH.ISSUES,
      filteredSearchTokenKeys: IssuableFilteredSearchTokenKeys,
    });
    manager.setup();
  };

  const findSearchInput = () => document.querySelector('.filtered-search');
  const findTokensContainer = () => document.querySelector('.tokens-container');
  const createVisualToken = (name, operator, value) => {
    findTokensContainer().appendChild(
      FilteredSearchSpecHelper.createFilterVisualToken(name, operator, value),
    );
  };

  beforeEach(() => {
    setFixtures(`
      <div class="filtered-search-box">
        <form>
          <ul class="tokens-container list-unstyled">
            ${FilteredSearchSpecHelper.createInputHTML()}
          </ul>
          <button class="clear-search" type="button">
            <i class="fa fa-times"></i>
          </button>
        </form>
      </div>
    `);

    const search = findSearchInput();
    search.dataset.epicsEndpoint = TEST_EPICS_ENDPOINT;

    jest.spyOn(FilteredSearchDropdownManager.prototype, 'setDropdown').mockImplementation();
  });

  afterEach(() => {
    manager.cleanup();
  });

  describe('getSearchTokens', () => {
    describe('Epic token', () => {
      beforeEach(() => {
        createSubject();
      });

      it.each`
        token                                           | extraTokens
        ${{ key: 'epic', operator: '=', value: '1' }}   | ${[{ key: 'include_subepics', operator: '=', value: '✓', symbol: '' }]}
        ${{ key: 'epic', operator: '=', value: 'any' }} | ${[]}
        ${{ key: 'epic', operator: '!=', value: '1' }}  | ${[]}
      `('handles include_subepics with $token', ({ token, extraTokens }) => {
        createVisualToken(token.key, token.operator, token.value);
        const { tokens } = manager.getSearchTokens();

        expect(tokens).toEqual([
          { key: token.key, operator: token.operator, value: token.value.toString(), symbol: '' },
          ...extraTokens,
        ]);
      });
    });
  });
});
