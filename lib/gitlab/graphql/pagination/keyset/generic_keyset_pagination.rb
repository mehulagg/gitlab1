# frozen_string_literal: true

module Gitlab
  module Graphql
    module Pagination
      module Keyset
        # Use the generic keyset implementation if the given ActiveRecord scope supports it.
        # Note: this module is temporary, at some point it will be merged with Keyset::Connection
        module GenericKeysetPagination
          extend ActiveSupport::Concern

          def ordered_items
            unless items.primary_key.present?
              raise ArgumentError.new('Relation must have a primary key')
            end

            return super unless Gitlab::Pagination::Keyset::Order.keyset_aware?(items)

            items
          end

          def cursor_for(node)
            return super unless Gitlab::Pagination::Keyset::Order.keyset_aware?(items)

            order = Gitlab::Pagination::Keyset::Order.extract_keyset_order_object(items)
            encode(order.cursor_attributes_for_node(node).to_json)
          end

          def slice_nodes(sliced, encoded_cursor, before_or_after)
            return super unless Gitlab::Pagination::Keyset::Order.keyset_aware?(sliced)

            order = Gitlab::Pagination::Keyset::Order.extract_keyset_order_object(sliced)
            order = order.reversed_order if before_or_after == :before

            decoded_cursor = ordering_from_encoded_json(encoded_cursor)
            order.apply_cursor_conditions(sliced, decoded_cursor)
          end

          def sliced_nodes
            return super unless Gitlab::Pagination::Keyset::Order.keyset_aware?(items)

            sliced = ordered_items
            sliced = slice_nodes(sliced, before, :before) if before.present?
            sliced = slice_nodes(sliced, after, :after) if after.present?
            sliced
          end

          def items
            original_items = super
            return original_items if Gitlab::Pagination::Keyset::Order.keyset_aware?(original_items) || Feature.disabled?(:new_graphql_keyset_pagination)

            rebuilt_items_with_keyset_order = Gitlab::Pagination::Keyset::SimpleOrderBuilder.build(original_items)

            if rebuilt_items_with_keyset_order.is_a?(Symbol) && rebuilt_items_with_keyset_order == :unable_to_order
              original_items
            else
              rebuilt_items_with_keyset_order
            end
          end
        end
      end
    end
  end
end
