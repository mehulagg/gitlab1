# frozen_string_literal: true

module Gitlab
  module Diff
    module FileCollection
      # Builds a paginated diff file collection and collects pagination
      # metadata.
      #
      # It doesn't handle caching yet as we're not prepared to write/read
      # separate file keys (https://gitlab.com/gitlab-org/gitlab/issues/30550).
      #
      class MergeRequestDiffBatch < MergeRequestDiffBase
        DEFAULT_BATCH_PAGE = 1
        DEFAULT_BATCH_SIZE = 30

        attr_reader :pagination_data

        def initialize(merge_request_diff, batch_page, batch_size, diff_options:)
          super(merge_request_diff, diff_options: diff_options)

          @paginated_collection = load_paginated_collection(batch_page, batch_size, diff_options)

          @pagination_data = {
            current_page: batch_gradual_load? ? nil : @paginated_collection.current_page,
            next_page: batch_gradual_load? ? nil : @paginated_collection.next_page,
            total_pages: batch_gradual_load? ? relation.size : @paginated_collection.total_pages
          }
        end

        override :diffs
        def diffs
          strong_memoize(:diffs) do
            @merge_request_diff.opening_external_diff do
              # Avoiding any extra queries.
              collection = @paginated_collection.to_a

              # The offset collection and calculation is required so that we
              # know how much has been loaded in previous batches, collapsing
              # the current paginated set accordingly (collection limit calculation).
              # See: https://docs.gitlab.com/ee/development/diffs.html#diff-collection-limits
              #
              offset_index = collection.first&.index
              options = diff_options.dup

              collection =
                if offset_index && offset_index > 0
                  offset_collection = relation.limit(offset_index) # rubocop:disable CodeReuse/ActiveRecord
                  options[:offset_index] = offset_index
                  offset_collection + collection
                else
                  collection
                end

              Gitlab::Git::DiffCollection.new(collection.map(&:to_hash), options)
            end
          end
        end

        private

        def relation
          @merge_request_diff.merge_request_diff_files
        end

        def load_paginated_collection(batch_page, batch_size, diff_options)
          batch_page ||= DEFAULT_BATCH_PAGE
          batch_size = [batch_size.to_i, DEFAULT_BATCH_SIZE].min

          paths = diff_options&.fetch(:paths, nil)

          paginated_collection = if batch_gradual_load?
                                  relation.offset(batch_page).limit(batch_size)
                                else
                                  relation.page(batch_page).per(batch_size)
                                end
          paginated_collection = paginated_collection.by_paths(paths) if paths

          paginated_collection
        end

        def batch_gradual_load?
          Feature.enabled?(:diffs_gradual_load, @merge_request_diff.project)
        end
      end
    end
  end
end
