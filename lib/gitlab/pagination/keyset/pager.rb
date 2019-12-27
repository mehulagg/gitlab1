# frozen_string_literal: true

module Gitlab
  module Pagination
    module Keyset
      class Pager
        attr_reader :request

        def initialize(request)
          @request = request
        end

        def paginate(relation)
          # Validate assumption: The last two columns must match the page order_by
          validate_order!(relation)

          # This performs the query and retrieves records
          relation.limit(page.per_page).load.tap do |records| # rubocop: disable CodeReuse/ActiveRecord
            apply_headers(records.last)
          end
        end

        private

        def apply_headers(last_record_in_page)
          end_reached = last_record_in_page.nil?
          lower_bounds = last_record_in_page&.slice(page.order_by.keys)

          next_page = page.next(lower_bounds, end_reached)

          request.apply_headers(next_page)
        end

        def page
          @page ||= request.page
        end

        def validate_order!(rel)
          present_order = rel.order_values.map { |val| [val.expr.name.to_sym, val.direction] }.last(2).to_h

          unless page.order_by == present_order
            raise ArgumentError, "Page's order_by does not match the relation's order: #{present_order} vs #{page.order_by}"
          end
        end
      end
    end
  end
end
