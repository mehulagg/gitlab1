# frozen_string_literal: true

class UserPresenter < Gitlab::View::Presenter::Delegated
  presents :user

  def group_memberships
    should_be_private? ? GroupMember.none : user.group_members
  end

  def project_memberships
    should_be_private? ? ProjectMember.none : user.project_members
  end

  private

  def should_be_private?
    !can?(current_user, :read_user_profile, user)
  end
end
