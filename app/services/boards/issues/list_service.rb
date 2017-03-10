module Boards
  module Issues
    class ListService < BaseService
      def execute
        issues = IssuesFinder.new(current_user, filter_params).execute
        issues = without_board_labels(issues) unless movable_list?
        issues = with_list_label(issues) if movable_list?
        issues.reorder(Gitlab::Database.nulls_last_order('relative_position', 'ASC'))
      end

      private

      def board
        @board ||= project.boards.find(params[:board_id])
      end

      def list
        return @list if defined?(@list)

        @list = board.lists.find(params[:id]) if params.key?(:id)
      end

      def movable_list?
        @movable_list ||= list.present? && list.movable?
      end

      def filter_params
        set_default_scope
        set_project
        set_state

        params
      end

      def set_default_scope
        params[:scope] = 'all'
      end

      def set_project
        params[:project_id] = project.id
      end

      def set_state
        params[:state] = list && list.done? ? 'closed' : 'opened'
      end

      def board_label_ids
        @board_label_ids ||= board.lists.movable.pluck(:label_id)
      end

      def without_board_labels(issues)
        return issues unless board_label_ids.any?

        issues.where.not(
          LabelLink.where("label_links.target_type = 'Issue' AND label_links.target_id = issues.id")
                   .where(label_id: board_label_ids).limit(1).arel.exists
        )
      end

      def with_list_label(issues)
        issues.where(
          LabelLink.where("label_links.target_type = 'Issue' AND label_links.target_id = issues.id")
                   .where("label_links.label_id = ?", list.label_id).limit(1).arel.exists
        )
      end
    end
  end
end
