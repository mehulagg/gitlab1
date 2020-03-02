# frozen_string_literal: true

class Groups::ApplicationController < ApplicationController
  include RoutableActions
  include ControllerWithCrossProjectAccessCheck

  layout 'group'

  skip_before_action :authenticate_user!
  before_action :group
  requires_cross_project_access

  set_current_tenant_through_filter
  before_action :set_namespace_as_tenant

  def set_namespace_as_tenant
    if group.nil? || group.root_ancestor.nil?
      logger.warn "Unable to set partition key because the ancestor chain was nil"
    else
      set_current_tenant(group.root_ancestor.path)
    end
  end

  private

  def group
    @group ||= find_routable!(Group, params[:group_id] || params[:id])
  end

  def group_projects
    @projects ||= GroupProjectsFinder.new(group: group, current_user: current_user).execute
  end

  def group_projects_with_subgroups
    @group_projects_with_subgroups ||= GroupProjectsFinder.new(
      group: group,
      current_user: current_user,
      options: { include_subgroups: true }
    ).execute
  end

  def authorize_admin_group!
    unless can?(current_user, :admin_group, group)
      return render_404
    end
  end

  def authorize_admin_group_member!
    unless can?(current_user, :admin_group_member, group)
      return render_403
    end
  end

  def build_canonical_path(group)
    params[:group_id] = group.to_param

    url_for(safe_params)
  end
end

Groups::ApplicationController.prepend_if_ee('EE::Groups::ApplicationController')
