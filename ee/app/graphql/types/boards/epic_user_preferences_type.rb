# frozen_string_literal: true

module Types
  module Boards
    # rubocop: disable Graphql/AuthorizeTypes
    class EpicUserPreferencesType < BaseObject
      graphql_name 'EpicUserPreferences'
      description 'Represents user preferences for a board epic'

      field :collapsed, GraphQL::BOOLEAN_TYPE, null: false,
            description: 'Whether epic should be collapsed'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
