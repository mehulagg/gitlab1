import FilterableList from '~/filterable_list';
import eventHub from './event_hub';
import { getParameterByName } from '../lib/utils/common_utils';

export default class GroupFilterableList extends FilterableList {
  constructor({ form, filter, holder, filterEndpoint, pagePath, dropdownSel, filterInputField }) {
    super(form, filter, holder, filterInputField);
    this.form = form;
    this.filterEndpoint = filterEndpoint;
    this.pagePath = pagePath;
    this.filterInputField = filterInputField;
    this.$dropdown = $(dropdownSel);
  }

  getFilterEndpoint() {
    return this.filterEndpoint;
  }

  getPagePath(queryData) {
    const params = queryData ? $.param(queryData) : '';
    const queryString = params ? `?${params}` : '';
    return `${this.pagePath}${queryString}`;
  }

  bindEvents() {
    super.bindEvents();

    this.onFilterOptionClikWrapper = this.onOptionClick.bind(this);

    this.$dropdown.on('click', 'a', this.onFilterOptionClikWrapper);
  }

  onFilterInput() {
    const queryData = {};
    const $form = $(this.form);
    const archivedParam = getParameterByName('archived', window.location.href);
    const filterGroupsParam = $form.find(`[name="${this.filterInputField}"]`).val();

    if (filterGroupsParam) {
      queryData[this.filterInputField] = filterGroupsParam;
    }

    if (archivedParam) {
      queryData.archived = archivedParam;
    }

    this.filterResults(queryData);

    if (this.setDefaultFilterOption) {
      this.setDefaultFilterOption();
    }
  }

  setDefaultFilterOption() {
    const defaultOption = $.trim(this.$dropdown.find('.dropdown-menu li.js-filter-sort-order a').first().text());
    this.$dropdown.find('.dropdown-label').text(defaultOption);
  }

  onOptionClick(e) {
    e.preventDefault();

    const queryData = {};

    // Get type of option selected from dropdown
    const currentTargetClassList = e.currentTarget.parentElement.classList;
    const isOptionFilterBySort = currentTargetClassList.contains('js-filter-sort-order');

    // Get option query param, also preserve currently applied query param
    const isOptionFilterByArchivedProjects = currentTargetClassList.contains('js-filter-archived-projects');
    const sortParam = getParameterByName('sort', e.currentTarget.href) || getParameterByName('sort', window.location.href);
    const archivedParam = getParameterByName('archived', e.currentTarget.href) || getParameterByName('archived', window.location.href);

    if (sortParam) {
      queryData.sort = sortParam;
    }

    if (archivedParam) {
      queryData.archived = archivedParam;
    }

    this.filterResults(queryData);

    // Active selected option
    if (isOptionFilterBySort) {
      this.$dropdown.find('.dropdown-label').text($.trim(e.currentTarget.text));
      this.$dropdown.find('.dropdown-menu li.js-filter-sort-order a').removeClass('is-active');
    } else if (isOptionFilterByArchivedProjects) {
      this.$dropdown.find('.dropdown-menu li.js-filter-archived-projects a').removeClass('is-active');
    }

    $(e.target).addClass('is-active');

    // Clear current value on search form
    this.form.querySelector(`[name="${this.filterInputField}"]`).value = '';
  }

  onFilterSuccess(data, xhr, queryData) {
    const currentPath = this.getPagePath(queryData);

    const paginationData = {
      'X-Per-Page': xhr.getResponseHeader('X-Per-Page'),
      'X-Page': xhr.getResponseHeader('X-Page'),
      'X-Total': xhr.getResponseHeader('X-Total'),
      'X-Total-Pages': xhr.getResponseHeader('X-Total-Pages'),
      'X-Next-Page': xhr.getResponseHeader('X-Next-Page'),
      'X-Prev-Page': xhr.getResponseHeader('X-Prev-Page'),
    };

    window.history.replaceState({
      page: currentPath,
    }, document.title, currentPath);

    eventHub.$emit('updateGroups', data, Object.prototype.hasOwnProperty.call(queryData, this.filterInputField));
    eventHub.$emit('updatePagination', paginationData);
  }
}
