# frozen_string_literal: true

module Autocomplete
  class UsersFinder
    include Gitlab::Utils::StrongMemoize

    # The number of users to display in the results is hardcoded to 20, and
    # pagination is not supported. This ensures that performance remains
    # consistent and removes the need for implementing keyset pagination to
    # ensure good performance.
    LIMIT = 20

    attr_reader :current_user, :project, :group, :search, :skip_users,
                :author_id, :todo_filter, :todo_state_filter,
                :filter_by_current_user

    def initialize(params:, current_user:, project:, group:)
      @current_user = current_user
      @project = project
      @group = group
      @search = params[:search]
      @skip_users = params[:skip_users]
      @author_id = params[:author_id]
      @participant_ids = params.fetch(:participant_ids, [])
      @todo_filter = params[:todo_filter]
      @todo_state_filter = params[:todo_state_filter]
      @filter_by_current_user = params[:current_user]
    end

    def execute
      items = limited_users

      if search.blank?
        # Include current user if available to filter by "Me"
        items.unshift(current_user) if prepend_current_user?

        items.unshift(author) if prepend_author? && author&.active?
      else
        to_prepend = find_users
          .active
          .id_in(prependable.map(&:id))
          .optionally_search(search)
          .to_a

        items = to_prepend + items
      end

      items = items.each_with_index
        .sort_by { |(user, i)| [*sort_order(user), i] }
        .map(&:first)

      items.uniq.tap do |unique_items|
        preload_associations(unique_items)
      end
    end

    private

    def prependable
      [
        prepend_author? && author,
        prepend_current_user? && current_user,
        *participants
      ].select(&:itself)
    end

    def sort_order(user)
      [user == current_user ? 0 : 1, user == author ? 0 : 1, participants.include?(user) ? 0 : 1]
    end

    def author
      strong_memoize(:author) do
        User.find_by_id(author_id)
      end
    end

    def participants
      strong_memoize(:participants) do
        User.id_in(participant_ids)
      end
    end

    # Returns the users based on the input parameters, as an Array.
    #
    # This method is separate so it is easier to extend in EE.
    def limited_users
      # When changing the order of these method calls, make sure that
      # reorder_by_name() is called _before_ optionally_search(), otherwise
      # reorder_by_name will break the ORDER BY applied in optionally_search().
      find_users
        .active
        .reorder_by_name
        .optionally_search(search)
        .where_not_in(skip_users)
        .limit_to_todo_authors(
          user: current_user,
          with_todos: todo_filter,
          todo_state: todo_state_filter
        )
        .limit(LIMIT)
        .to_a
    end

    def prepend_current_user?
      filter_by_current_user.present? && current_user
    end

    def prepend_author?
      author_id.present? && current_user
    end

    def find_users
      if project
        project.authorized_users.union_with_user(author_id)
      elsif group
        group.users_with_parents
      elsif current_user
        User.all
      else
        User.none
      end
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def preload_associations(items)
      ActiveRecord::Associations::Preloader.new.preload(items, :status)
    end
    # rubocop: enable CodeReuse/ActiveRecord
  end
end

Autocomplete::UsersFinder.prepend_if_ee('EE::Autocomplete::UsersFinder')
