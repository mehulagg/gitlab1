# frozen_string_literal: true

module EE
  module Issues
    module MoveService
      extend ::Gitlab::Utils::Override

      override :update_old_entity
      def update_old_entity
        rewrite_epic_issue
        duplicate_related_issues

        super
      end

      private

      def rewrite_epic_issue
        return unless epic_issue = original_entity.epic_issue
        return unless can?(current_user, :update_epic, epic_issue.epic.group)

        epic_issue.update(issue_id: new_entity.id)
        original_entity.reset
      end

      def duplicate_related_issues
        source_issue_links = IssueLink.for_source_issue(original_entity)
        target_issue_links = IssueLink.for_target_issue(original_entity)

        issue_links_attributes = source_issue_links
          .map { |issue_link| [new_entity.id, issue_link.target_id] }
          .concat(
            target_issue_links.map { |issue_link| [issue_link.source_id, new_entity.id] }
          )

        return if issue_links_attributes.empty?

        connection.execute(insert_sql_query(issue_links_attributes))
      end

      def insert_sql_query(issue_links)
        <<~SQL
        INSERT INTO #{IssueLink.table_name} (source_id, target_id)
        VALUES #{issue_links.map { |issue_link| "(#{issue_link.join(', ')})" }.join(', ')}
        SQL
      end

      def connection
        ActiveRecord::Base.connection
      end
    end
  end
end
