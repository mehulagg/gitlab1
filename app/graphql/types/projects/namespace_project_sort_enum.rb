# frozen_string_literal: true

module Types
  module Projects
    class NamespaceProjectSortEnum < BaseEnum
      graphql_name 'NamespaceProjectSort'
      description 'Values for sorting projects'

      value 'SIMILARITY', 'Most similar to the search query', value: :similarity
    end
  end
end
