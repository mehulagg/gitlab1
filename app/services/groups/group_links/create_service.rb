# frozen_string_literal: true

module Groups
  module GroupLinks
    class CreateService < Groups::BaseService
      def execute(shared_group)
        unless group && shared_group &&
               can?(current_user, :admin_group_member, shared_group) &&
               can?(current_user, :read_group, group) &&
               group_share_hierarchy_lock_check(shared_group, group)
          return error('Not Found', 404)
        end

        link = GroupGroupLink.new(
          shared_group: shared_group,
          shared_with_group: group,
          group_access: params[:shared_group_access],
          expires_at: params[:expires_at]
        )

        if link.save
          group.refresh_members_authorized_projects(direct_members_only: true)
          success(link: link)
        else
          error(link.errors.full_messages.to_sentence, 409)
        end
      end

      private

      def group_share_hierarchy_lock_check(group, shared_group)
        root_group = group.root_ancestor

        if root_group.share_within_hierarchy_lock
          root_group.self_and_descendants.ids.include?(shared_group.id)
        else
          true
        end
      end
    end
  end
end
