# frozen_string_literal: true

module Types
  class BoardType < BaseObject
    graphql_name 'Board'
    description 'Represents a project or group board'
    accepts ::Board
    authorize :read_board

    present_using BoardPresenter

    field :id, type: GraphQL::ID_TYPE, null: false,
          description: 'ID (global ID) of the board'
    field :name, type: GraphQL::STRING_TYPE, null: true,
          description: 'Name of the board'

    field :hide_backlog_list, type: GraphQL::BOOLEAN_TYPE, null: true,
          description: 'Whether or not backlog list is hidden'

    field :hide_closed_list, type: GraphQL::BOOLEAN_TYPE, null: true,
          description: 'Whether or not closed list is hidden'

    field :lists,
          Types::BoardListType.connection_type,
          null: true,
          description: 'Lists of the board',
          resolver: Resolvers::BoardListsResolver,
          extras: [:lookahead]

    field :board_type,
          ::Types::Boards::TypeEnum,
          null: true,
          description: 'Type of board'

    field :web_path, GraphQL::STRING_TYPE, null: false,
          description: 'Web path of the board.'

    field :web_url, GraphQL::STRING_TYPE, null: false,
          description: 'Web URL of the board.'
  end
end

Types::BoardType.prepend_if_ee('::EE::Types::BoardType')
