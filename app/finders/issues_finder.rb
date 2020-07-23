# frozen_string_literal: true

# Finders::Issues class
#
# Used to filter Issues collections by set of params
#
# Arguments:
#   current_user - which user use
#   params:
#     scope: 'created_by_me' or 'assigned_to_me' or 'all'
#     state: 'open' or 'closed' or 'all'
#     group_id: integer
#     project_id: integer
#     milestone_title: string
#     assignee_id: integer
#     search: string
#     in: 'title', 'description', or a string joining them with comma
#     label_name: string
#     sort: string
#     my_reaction_emoji: string
#     public_only: boolean
#     due_date: date or '0', '', 'overdue', 'week', or 'month'
#     created_after: datetime
#     created_before: datetime
#     updated_after: datetime
#     updated_before: datetime
#     confidential: boolean
#
class IssuesFinder < IssuableFinder
  CONFIDENTIAL_ACCESS_LEVEL = Gitlab::Access::REPORTER

  def self.scalar_params
    @scalar_params ||= super + [:due_date]
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def klass
    Issue.includes(:author)
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def params_class
    IssuesFinder::Params
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def with_confidentiality_access_check
    return Issue.all if params.user_can_see_all_confidential_issues?
    return Issue.where('issues.confidential IS NOT TRUE') if params.user_cannot_see_confidential_issues?

    Issue.where('
      issues.confidential IS NOT TRUE
      OR (issues.confidential = TRUE
        AND (issues.author_id = :user_id
          OR EXISTS (SELECT TRUE FROM issue_assignees WHERE user_id = :user_id AND issue_id = issues.id)
          OR EXISTS (:authorizations)))',
      user_id: current_user.id,
      authorizations: current_user.authorizations_for_projects(min_access_level: CONFIDENTIAL_ACCESS_LEVEL, related_project_column: "issues.project_id"))
  end
  # rubocop: enable CodeReuse/ActiveRecord

  private

  def init_collection
    if params.public_only?
      Issue.public_only
    else
      with_confidentiality_access_check
    end
  end

  def filter_items(items)
    issues = super
    issues = by_due_date(issues)
    issues = by_confidential(issues)
    issues
  end

  def by_confidential(items)
    return items if params[:confidential].nil?

    params[:confidential] ? items.confidential_only : items.public_only
  end

  def by_due_date(items)
    return items unless params.due_date?

    if params.filter_by_no_due_date?
      items.without_due_date
    elsif params.filter_by_overdue?
      items.due_before(Date.today)
    elsif params.filter_by_due_this_week?
      items.due_between(Date.today.beginning_of_week, Date.today.end_of_week)
    elsif params.filter_by_due_this_month?
      items.due_between(Date.today.beginning_of_month, Date.today.end_of_month)
    elsif params.filter_by_due_next_month_and_previous_two_weeks?
      items.due_between(Date.today - 2.weeks, (Date.today + 1.month).end_of_month)
    end
  end
end

IssuesFinder.prepend_if_ee('EE::IssuesFinder')
