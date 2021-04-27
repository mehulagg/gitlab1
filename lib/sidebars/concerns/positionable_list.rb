# frozen_string_literal: true

# This module handles element positions in a list.
module Sidebars
  module Concerns
    module PositionableList
      def add_element(list, element)
        return unless element

        list << element
      end

      def insert_element_before(list, before_element, new_element)
        return unless new_element

        index = index_of(list, before_element)

        if index
          list.insert(index, new_element)
        else
          list.unshift(new_element)
        end
      end

      def insert_element_after(list, after_element, new_element)
        return unless new_element

        index = index_of(list, after_element)

        if index
          list.insert(index + 1, new_element)
        else
          add_element(list, new_element)
        end
      end

      private

      # Classes including this method will have to define
      # the way to identify elements through this method
      def index_of(list, element)
        raise NotImplementedError
      end
    end
  end
end
