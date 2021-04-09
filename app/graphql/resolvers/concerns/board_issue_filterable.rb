# frozen_string_literal: true

module BoardIssueFilterable
  extend ActiveSupport::Concern

  private

  def issue_filters(args)
    filters = args.to_h
    set_filter_values(filters)

    if filters[:not]
      filters[:not] = filters[:not].to_h
      set_filter_values(filters[:not])
    end

    filters
  end

  def set_filter_values(filters)
    filter_by_assignee(filters)
  end

  def filter_by_assignee(filters)
    assignee_username = filters.delete(:assignee_username)
    assignee_wildcard_id = filters.delete(:assignee_wildcard_id)

    if assignee_username && assignee_wildcard_id
      raise ::Gitlab::Graphql::Errors::ArgumentError, 'Incompatible arguments: assigneeUsername, assigneeWildcardId.'
    end

    if assignee_username
      filters[:assignee_username] = assignee_username
    elsif assignee_wildcard_id
      filters[:assignee_id] = assignee_wildcard_id
    end
  end
end

::BoardIssueFilterable.prepend_if_ee('::EE::Resolvers::BoardIssueFilterable')
