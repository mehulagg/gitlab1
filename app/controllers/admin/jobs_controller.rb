# frozen_string_literal: true

class Admin::JobsController < Admin::ApplicationController
  BUILDS_PER_PAGE = 30

  def index
    # We need all builds for tabs counters
    @all_builds = Ci::JobsFinder.new.execute

    @scope = params[:scope]
    @builds = Ci::JobsFinder.new(params: params).execute
    @builds = @builds.eager_load_everything
    @builds = @builds.page(params[:page]).per(BUILDS_PER_PAGE).without_count
  end

  def cancel_all
    Ci::Build.running_or_pending.each(&:cancel)

    redirect_to admin_jobs_path, status: :see_other
  end
end
