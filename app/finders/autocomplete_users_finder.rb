class AutocompleteUsersFinder
  # The number of users to display in the results is hardcoded to 20, and
  # pagination is not supported. This ensures that performance remains
  # consistent and removes the need for implementing keyset pagination to ensure
  # good performance.
  LIMIT = 20

  attr_reader :current_user, :project, :group, :search, :skip_users,
              :author_id, :params

  # EE
  attr_reader :skip_ldap

  def initialize(params:, current_user:, project:, group:)
    @current_user = current_user
    @project = project
    @group = group
    @search = params[:search]
    @skip_users = params[:skip_users]
    @author_id = params[:author_id]
    @params = params

    # EE
    @skip_ldap = params[:skip_ldap]
  end

  def execute
    items = find_users

    # EE
    items = items.non_ldap if skip_ldap == 'true'

    items = items.active
    items = items.reorder(:name)
    items = items.search(search) if search.present?
    items = items.where.not(id: skip_users) if skip_users.present?
    items = items.limit(LIMIT)

    # EE
    items = load_users_by_push_ability(items)

    if params[:todo_filter].present? && current_user
      items = items.todo_authors(current_user.id, params[:todo_state_filter])
    end

    if search.blank?
      # Include current user if available to filter by "Me"
      if params[:current_user].present? && current_user
        items = [current_user, *items].uniq
      end

      if author_id.present? && current_user
        author = User.find_by_id(author_id)
        items = [author, *items].uniq if author
      end
    end

    items
  end

  private

  def find_users
    return users_from_project if project
    return group.users_with_parents if group
    return User.all if current_user

    User.none
  end

  def users_from_project
    if author_id.present?
      union = Gitlab::SQL::Union
        .new([project.authorized_users, User.where(id: author_id)])

      User.from("(#{union.to_sql}) #{User.table_name}")
    else
      project.authorized_users
    end
  end

  # EE
  def load_users_by_push_ability(items)
    return items unless project

    ability = push_ability
    return items if ability.blank?

    items.to_a
      .select { |user| user.can?(ability, project) }
  end

  def push_ability
    if params[:push_code_to_protected_branches].present?
      :push_code_to_protected_branches
    elsif params[:push_code].present?
      :push_code
    end
  end
  # EE
end
