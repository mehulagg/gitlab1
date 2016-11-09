/* eslint-disable no-param-reassign */
((global) => {
  const validTokenKeys = [{
    key: 'author',
    type: 'string',
    param: 'username',
  }, {
    key: 'assignee',
    type: 'string',
    param: 'username',
  }, {
    key: 'milestone',
    type: 'string',
    param: 'title',
  }, {
    key: 'label',
    type: 'array',
    param: 'name[]',
  }];

  function clearSearch(event) {
    event.stopPropagation();
    event.preventDefault();

    document.querySelector('.filtered-search').value = '';
    document.querySelector('.clear-search').classList.add('hidden');
  }

  function toggleClearSearchButton(event) {
    const clearSearchButton = document.querySelector('.clear-search');

    if (event.target.value) {
      clearSearchButton.classList.remove('hidden');
    } else {
      clearSearchButton.classList.add('hidden');
    }
  }

  function loadSearchParamsFromURL() {
    // We can trust that each param has one & since values containing & will be encoded
    // Remove the first character of search as it is always ?
    const params = window.location.search.slice(1).split('&');
    let inputValue = '';

    params.forEach((p) => {
      const split = p.split('=');
      const key = decodeURIComponent(split[0]);
      const value = split[1];

      // Sanitize value since URL converts spaces into +
      // Replace before decode so that we know what was originally + versus the encoded +
      const sanitizedValue = value ? decodeURIComponent(value.replace(/[+]/g, ' ')) : value;
      const match = validTokenKeys.find(t => key === `${t.key}_${t.param}`);

      if (match) {
        const sanitizedKey = key.slice(0, key.indexOf('_'));
        const valueHasSpace = sanitizedValue.indexOf(' ') !== -1;

        const preferredQuotations = '"';
        let quotationsToUse = preferredQuotations;

        if (valueHasSpace) {
          // Prefer ", but use ' if required
          quotationsToUse = sanitizedValue.indexOf(preferredQuotations) === -1 ? preferredQuotations : '\'';
        }

        inputValue += valueHasSpace ? `${sanitizedKey}:${quotationsToUse}${sanitizedValue}${quotationsToUse}` : `${sanitizedKey}:${sanitizedValue}`;
        inputValue += ' ';
      } else if (!match && key === 'search') {
        inputValue += sanitizedValue;
        inputValue += ' ';
      }
    });

    // Trim the last space value
    document.querySelector('.filtered-search').value = inputValue.trim();

    if (inputValue.trim()) {
      document.querySelector('.clear-search').classList.remove('hidden');
    }
  }

  class FilteredSearchManager {
    constructor() {
      this.tokenizer = new gl.FilteredSearchTokenizer(validTokenKeys);
      this.bindEvents();
      loadSearchParamsFromURL();
    }

    bindEvents() {
      const filteredSearchInput = document.querySelector('.filtered-search');

      filteredSearchInput.addEventListener('input', this.processInput.bind(this));
      filteredSearchInput.addEventListener('input', toggleClearSearchButton);
      filteredSearchInput.addEventListener('keydown', this.checkForEnter.bind(this));

      document.querySelector('.clear-search').addEventListener('click', clearSearch);
    }

    processInput(event) {
      const input = event.target.value;
      this.tokenizer.processTokens(input);
    }

    checkForEnter(event) {
      if (event.key === 'Enter') {
        event.stopPropagation();
        event.preventDefault();
        this.search();
      }
    }

    search() {
      console.log('search');
      let path = '?scope=all&utf8=✓';

      // Check current state
      const currentPath = window.location.search;
      const stateIndex = currentPath.indexOf('state=');
      const defaultState = 'opened';
      let currentState = defaultState;

      const tokens = this.tokenizer.getTokens();
      const searchToken = this.tokenizer.getSearchToken();

      if (stateIndex !== -1) {
        const remaining = currentPath.slice(stateIndex + 6);
        const separatorIndex = remaining.indexOf('&');

        currentState = separatorIndex === -1 ? remaining : remaining.slice(0, separatorIndex);
      }

      path += `&state=${currentState}`;
      tokens.forEach((token) => {
        const param = validTokenKeys.find(t => t.key === token.key).param;
        path += `&${token.key}_${param}=${encodeURIComponent(token.value)}`;
      });

      if (searchToken) {
        path += `&search=${encodeURIComponent(searchToken)}`;
      }

      window.location = path;
    }
  }

  global.FilteredSearchManager = FilteredSearchManager;
})(window.gl || (window.gl = {}));
