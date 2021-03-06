<script>
import {
  GlAvatar,
  GlAvatarLabeled,
  GlIcon,
  GlFormGroup,
  GlFormRadio,
  GlFormRadioGroup,
  GlTooltipDirective as GlTooltip,
} from '@gitlab/ui';
import { mapActions, mapGetters, mapState } from 'vuex';
import BoardAddNewColumnForm from '~/boards/components/board_add_new_column_form.vue';
import { ListType } from '~/boards/constants';
import boardsStore from '~/boards/stores/boards_store';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { isScopedLabel } from '~/lib/utils/common_utils';
import { __ } from '~/locale';

export const listTypeInfo = {
  [ListType.label]: {
    listPropertyName: 'labels',
    loadingPropertyName: 'labelsLoading',
    fetchMethodName: 'fetchLabels',
    noneSelected: __('Select a label'),
    searchPlaceholder: __('Search labels'),
  },
  [ListType.assignee]: {
    listPropertyName: 'assignees',
    loadingPropertyName: 'assigneesLoading',
    fetchMethodName: 'fetchAssignees',
    noneSelected: __('Select an assignee'),
    searchPlaceholder: __('Search assignees'),
  },
  [ListType.milestone]: {
    listPropertyName: 'milestones',
    loadingPropertyName: 'milestonesLoading',
    fetchMethodName: 'fetchMilestones',
    noneSelected: __('Select a milestone'),
    searchPlaceholder: __('Search milestones'),
  },
  [ListType.iteration]: {
    listPropertyName: 'iterations',
    loadingPropertyName: 'iterationsLoading',
    fetchMethodName: 'fetchIterations',
    noneSelected: __('Select an iteration'),
    searchPlaceholder: __('Search iterations'),
  },
};

export default {
  i18n: {
    value: __('Value'),
  },
  components: {
    BoardAddNewColumnForm,
    GlAvatar,
    GlAvatarLabeled,
    GlIcon,
    GlFormGroup,
    GlFormRadio,
    GlFormRadioGroup,
  },
  directives: {
    GlTooltip,
  },
  inject: [
    'scopedLabelsAvailable',
    'milestoneListsAvailable',
    'assigneeListsAvailable',
    'iterationListsAvailable',
  ],
  data() {
    return {
      selectedId: null,
      selectedItem: null,
      columnType: ListType.label,
    };
  },
  computed: {
    ...mapState([
      'labels',
      'labelsLoading',
      'milestones',
      'milestonesLoading',
      'iterations',
      'iterationsLoading',
      'assignees',
      'assigneesLoading',
    ]),
    ...mapGetters(['getListByTypeId', 'shouldUseGraphQL', 'isEpicBoard']),

    info() {
      return listTypeInfo[this.columnType] || {};
    },

    items() {
      return this[this.info.listPropertyName] || [];
    },

    hasItems() {
      return this.items.length > 0;
    },

    labelTypeSelected() {
      return this.columnType === ListType.label;
    },
    assigneeTypeSelected() {
      return this.columnType === ListType.assignee;
    },
    milestoneTypeSelected() {
      return this.columnType === ListType.milestone;
    },
    iterationTypeSelected() {
      return this.columnType === ListType.iteration;
    },

    hasLabelSelection() {
      return this.labelTypeSelected && this.selectedItem;
    },
    hasMilestoneSelection() {
      return this.milestoneTypeSelected && this.selectedItem;
    },
    hasIterationSelection() {
      return this.iterationTypeSelected && this.selectedItem;
    },
    hasAssigneeSelection() {
      return this.assigneeTypeSelected && this.selectedItem;
    },

    columnForSelected() {
      if (!this.columnType || !this.selectedId) {
        return false;
      }

      if (this.shouldUseGraphQL || this.isEpicBoard) {
        const key = `${this.columnType}Id`;
        return this.getListByTypeId({
          [key]: this.selectedId,
        });
      }

      return boardsStore.state.lists.find(
        (list) => list[this.columnType]?.id === getIdFromGraphQLId(this.selectedId),
      );
    },

    loading() {
      return this[this.info.loadingPropertyName];
    },

    columnTypes() {
      const types = [{ value: ListType.label, text: __('Label') }];

      if (this.assigneeListsAvailable) {
        types.push({ value: ListType.assignee, text: __('Assignee') });
      }

      if (this.milestoneListsAvailable) {
        types.push({ value: ListType.milestone, text: __('Milestone') });
      }

      if (this.iterationListsAvailable) {
        types.push({ value: ListType.iteration, text: __('Iteration') });
      }

      return types;
    },

    searchLabel() {
      return this.showListTypeSelector ? this.$options.i18n.value : null;
    },

    showListTypeSelector() {
      return !this.isEpicBoard && this.columnTypes.length > 1;
    },
  },
  created() {
    this.filterItems();
  },
  methods: {
    ...mapActions([
      'createList',
      'fetchLabels',
      'highlightList',
      'setAddColumnFormVisibility',
      'fetchAssignees',
      'fetchIterations',
      'fetchMilestones',
    ]),
    highlight(listId) {
      if (this.shouldUseGraphQL || this.isEpicBoard) {
        this.highlightList(listId);
      } else {
        const list = boardsStore.state.lists.find(({ id }) => id === listId);
        list.highlighted = true;
        setTimeout(() => {
          list.highlighted = false;
        }, 2000);
      }
    },
    addList() {
      if (!this.selectedItem) {
        return;
      }

      this.setAddColumnFormVisibility(false);

      if (this.columnForSelected) {
        const listId = this.columnForSelected.id;
        this.highlight(listId);
        return;
      }

      if (this.shouldUseGraphQL || this.isEpicBoard) {
        // eslint-disable-next-line @gitlab/require-i18n-strings
        this.createList({ [`${this.columnType}Id`]: this.selectedId });
      } else {
        const { length } = boardsStore.state.lists;
        const position = this.hideClosed ? length - 1 : length - 2;
        const listObj = {
          // eslint-disable-next-line @gitlab/require-i18n-strings
          [`${this.columnType}Id`]: getIdFromGraphQLId(this.selectedId),
          title: this.selectedItem.title,
          position,
          list_type: this.columnType,
        };

        if (this.labelTypeSelected) {
          listObj.label = this.selectedItem;
        } else if (this.milestoneTypeSelected) {
          listObj.milestone = {
            ...this.selectedItem,
            id: getIdFromGraphQLId(this.selectedItem.id),
          };
        } else if (this.iterationTypeSelected) {
          listObj.iteration = {
            ...this.selectedItem,
            id: getIdFromGraphQLId(this.selectedItem.id),
          };
        } else if (this.assigneeTypeSelected) {
          listObj.assignee = {
            ...this.selectedItem,
            id: getIdFromGraphQLId(this.selectedItem.id),
          };
        }

        boardsStore.new(listObj);
      }
    },

    filterItems(searchTerm) {
      this[this.info.fetchMethodName](searchTerm);
    },

    showScopedLabels(label) {
      return this.scopedLabelsAvailable && isScopedLabel(label);
    },

    setColumnType(type) {
      this.columnType = type;
      this.selectedId = null;
      this.setSelectedItem(null);
      this.filterItems();
    },

    setSelectedItem(selectedId) {
      const item = this.items.find(({ id }) => id === selectedId);
      if (!selectedId || !item) {
        this.selectedItem = null;
      } else {
        this.selectedItem = { ...item };
      }
    },
  },
};
</script>

<template>
  <board-add-new-column-form
    :loading="loading"
    :none-selected="info.noneSelected"
    :search-label="searchLabel"
    :search-placeholder="info.searchPlaceholder"
    :selected-id="selectedId"
    @filter-items="filterItems"
    @add-list="addList"
  >
    <template #select-list-type>
      <gl-form-group
        v-if="showListTypeSelector"
        :description="$options.i18n.scopeDescription"
        class="gl-px-5 gl-py-0 gl-mb-3"
        label-for="list-type"
      >
        <gl-form-radio-group v-model="columnType">
          <gl-form-radio
            v-for="{ text, value } in columnTypes"
            :key="value"
            :value="value"
            class="gl-mb-0 gl-align-self-center"
            @change="setColumnType"
          >
            {{ text }}
          </gl-form-radio>
        </gl-form-radio-group>
      </gl-form-group>
    </template>

    <template #selected>
      <template v-if="hasLabelSelection">
        <span
          class="dropdown-label-box gl-top-0 gl-flex-shrink-0"
          :style="{
            backgroundColor: selectedItem.color,
          }"
        ></span>
        <div class="gl-text-truncate">{{ selectedItem.title }}</div>
      </template>

      <template v-else-if="hasMilestoneSelection">
        <gl-icon class="gl-flex-shrink-0" name="clock" />
        <span class="gl-text-truncate">{{ selectedItem.title }}</span>
      </template>

      <template v-else-if="hasIterationSelection">
        <gl-icon class="gl-flex-shrink-0" name="iteration" />
        <span class="gl-text-truncate">{{ selectedItem.title }}</span>
      </template>

      <template v-else-if="hasAssigneeSelection">
        <gl-avatar class="gl-mr-2 gl-flex-shrink-0" :size="16" :src="selectedItem.avatarUrl" />
        <div class="gl-text-truncate">
          <b class="gl-mr-2">{{ selectedItem.name }}</b>
          <span class="gl-text-gray-700">@{{ selectedItem.username }}</span>
        </div>
      </template>
    </template>

    <template v-if="hasItems" #items>
      <gl-form-radio-group
        v-model="selectedId"
        class="gl-overflow-y-auto gl-px-5"
        data-testid="selectItem"
        @change="setSelectedItem"
      >
        <label
          v-for="item in items"
          :key="item.id"
          class="gl-display-flex gl-font-weight-normal gl-overflow-break-word gl-py-3 gl-mb-0"
        >
          <gl-form-radio
            :value="item.id"
            :class="assigneeTypeSelected ? 'gl-align-self-center' : ''"
          />
          <span
            v-if="labelTypeSelected"
            class="dropdown-label-box gl-top-0 gl-flex-shrink-0"
            :style="{
              backgroundColor: item.color,
            }"
          ></span>

          <gl-avatar-labeled
            v-if="assigneeTypeSelected"
            class="gl-display-flex gl-align-items-center"
            :size="32"
            :label="item.name"
            :sub-label="`@${item.username}`"
            :src="item.avatarUrl"
          />
          <span v-else>{{ item.title }}</span>
        </label>
      </gl-form-radio-group>

      <div class="dropdown-content-faded-mask gl-fixed gl-bottom-0 gl-w-full"></div>
    </template>
  </board-add-new-column-form>
</template>
