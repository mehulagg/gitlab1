# frozen_string_literal: true

module Resolvers
  class BoardListIssuesResolver < BaseResolver
    include BoardIssueFilterable

    argument :filters, Types::Boards::BoardIssueInputType,
             required: false,
             description: 'Filters applied when selecting issues in the board list'

    type Types::IssueType, null: true

    alias_method :list, :object

    def resolve(**args)
      filter_params = issue_filters(args[:filters]).merge(board_id: list.board.id, id: list.id)
      service = ::Boards::Issues::ListService.new(list.board.resource_parent, context[:current_user], filter_params)

      Gitlab::Graphql::Pagination::OffsetActiveRecordRelationConnection.new(service.execute)
    end

    # https://gitlab.com/gitlab-org/gitlab/-/issues/235681
    def self.complexity_multiplier(args)
      0.005
    end
  end
end
