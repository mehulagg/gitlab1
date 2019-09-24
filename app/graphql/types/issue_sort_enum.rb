# frozen_string_literal: true

module Types
  # rubocop: disable Graphql/AuthorizeTypes
  class IssueSortEnum < SortEnum
    graphql_name 'IssueSort'
    description 'Sort issues'

    value 'DUE_DATE_ASC', 'Due date by ascending order', value: :due_date_asc
    value 'DUE_DATE_DESC', 'Due date by descending order', value: :due_date_desc
  end
  # rubocop: enable Graphql/AuthorizeTypes
end
