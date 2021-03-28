# frozen_string_literal: true

module EE
  module Label
    extend ActiveSupport::Concern

    SCOPED_LABEL_SEPARATOR = '::'
    SCOPED_LABEL_PATTERN = /^.*#{SCOPED_LABEL_SEPARATOR}/.freeze

    prepended do
      has_many :epic_board_labels, class_name: 'Boards::EpicBoardLabel', inverse_of: :label
      has_many :epic_lists, class_name: 'Boards::EpicList', inverse_of: :label

      scope :with_epic_lists_and_board, -> { joins(epic_lists: :epic_board).merge(::Boards::EpicList.movable) }
      scope :on_epic_board, ->(epic_board_id) { with_epic_lists_and_board.where(boards_epic_boards: { id: epic_board_id }) }

      def self.ids_on_epic_board(epic_board_id)
        on_epic_board(epic_board_id).pluck(:label_id)
      end
    end

    def scoped_label?
      SCOPED_LABEL_PATTERN.match?(name)
    end

    def scoped_label_key
      title[Label::SCOPED_LABEL_PATTERN]&.delete_suffix(SCOPED_LABEL_SEPARATOR)
    end

    def scoped_label_value
      title.sub(SCOPED_LABEL_PATTERN, '')
    end
  end
end
