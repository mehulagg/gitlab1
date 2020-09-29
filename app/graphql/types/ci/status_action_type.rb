# frozen_string_literal: true
module Types
  module Ci
    # rubocop: disable Graphql/AuthorizeTypes
    class StatusActionType < BaseObject
      graphql_name 'StatusAction'

      field :button_title, GraphQL::STRING_TYPE, null: true,
            description: 'Title for the button, for example: Retry this job'
      field :icon, GraphQL::STRING_TYPE, null: true,
            description: 'Icon used in the action button'
      field :action_method, GraphQL::STRING_TYPE, null: true,
            description: 'Method for the action, for example: :post'
      field :path, GraphQL::STRING_TYPE, null: true,
            description: 'Path for the action'
      field :title, GraphQL::STRING_TYPE, null: true,
            description: 'Title for the action, for example: Retry'
    end
  end
end
