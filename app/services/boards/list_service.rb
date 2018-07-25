# frozen_string_literal: true

module Boards
  class ListService < Boards::BaseService
    prepend EE::Boards::ListService

    def execute
      create_board! if parent.boards.empty?
      boards
    end

    private

    def boards
      parent.boards
    end

    def create_board!
      Boards::CreateService.new(parent, current_user).execute
    end
  end
end
