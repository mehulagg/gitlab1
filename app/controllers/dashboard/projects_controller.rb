# frozen_string_literal: true

class Dashboard::ProjectsController < Dashboard::ApplicationController
  include ParamsBackwardCompatibility
  include RendersMemberAccess
  include OnboardingExperimentHelper
  include SortingHelper
  include SortingPreference

  prepend_before_action(only: [:index]) { authenticate_sessionless_user!(:rss) }
  before_action :ensure_admin!, only: [:removed]
  before_action :set_non_archived_param, except: [:removed]
  before_action :set_sorting
  before_action :projects, only: [:index]
  skip_cross_project_access_check :index, :starred

  def index
    respond_to do |format|
      format.html do
        render_projects
      end
      format.atom do
        load_events
        render layout: 'xml.atom'
      end
      format.json do
        render json: {
          html: view_to_html_string("dashboard/projects/_projects", projects: @projects)
        }
      end
    end
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def starred
    @projects = load_projects(params.merge(starred: true))
      .includes(:forked_from_project, :tags)

    @groups = []

    respond_to do |format|
      format.html
      format.json do
        render json: {
          html: view_to_html_string("dashboard/projects/_projects", projects: @projects)
        }
      end
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def removed
    @projects = load_projects(params.merge(marked_for_deletion: true))

    respond_to do |format|
      format.html
      format.json do
        render json: {
          html: view_to_html_string("dashboard/projects/_projects", projects: @projects)
        }
      end
    end
  end

  private

  def projects
    @projects ||= load_projects(params.merge(non_public: true))
  end

  def render_projects
    # n+1: https://gitlab.com/gitlab-org/gitlab-foss/issues/40260
    Gitlab::GitalyClient.allow_n_plus_1_calls do
      render
    end
  end

  def load_projects(finder_params)
    @total_user_projects_count = ProjectsFinder.new(params: { non_public: true }, current_user: current_user).execute
    @total_starred_projects_count = ProjectsFinder.new(params: { starred: true }, current_user: current_user).execute
    @removed_projects_count = ProjectsFinder.new(params: { marked_for_deletion: true }, current_user: current_user).execute

    finder_params[:use_cte] = true if use_cte_for_finder?

    projects = ProjectsFinder.new(params: finder_params, current_user: current_user).execute

    projects = preload_associations(projects)
    projects = projects.page(finder_params[:page])

    prepare_projects_for_rendering(projects)
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def preload_associations(projects)
    projects.includes(:route, :creator, :group, namespace: [:route, :owner]).preload(:project_feature)
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def use_cte_for_finder?
    # The starred action loads public projects, which causes the CTE to be less efficient
    action_name == 'index'
  end

  def load_events
    projects = ProjectsFinder
                .new(params: params.merge(non_public: true), current_user: current_user)
                .execute

    @events = EventCollection
      .new(projects, offset: params[:offset].to_i, filter: event_filter)
      .to_a

    Events::RenderService.new(current_user).execute(@events, atom_request: request.format.atom?)
  end

  def set_sorting
    params[:sort] = set_sort_order
    @sort = params[:sort]
  end

  def default_sort_order
    sort_value_latest_activity
  end

  def sorting_field
    Project::SORTING_PREFERENCE_FIELD
  end

  def ensure_admin!
    return render_404 unless current_user.admin?
  end

end

Dashboard::ProjectsController.prepend_if_ee('EE::Dashboard::ProjectsController')
