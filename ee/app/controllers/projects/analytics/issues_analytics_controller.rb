# frozen_string_literal: true

class Projects::Analytics::IssuesAnalyticsController < Projects::ApplicationController
  include IssuableCollections
  include ::Analytics::UniqueVisitsHelper

  before_action :authorize_read_issue_analytics!

  track_unique_visits :show, target_id: 'p_analytics_issues'

  feature_category :planning_analytics

  def show
    respond_to do |format|
      format.html

      format.json do
        if Feature.enabled?(:new_issues_analytics_chart_data, project.namespace)
          @chart_data = Analytics::IssuesAnalytics.new(issuables: issuables_collection, months_back: params[:months_back])
            .monthly_counters
        else
          @chart_data =
            IssuablesAnalytics.new(issuables: issuables_collection, months_back: params[:months_back]).data
        end

        render json: @chart_data
      end
    end
  end

  private

  def authorize_read_issue_analytics!
    render_404 unless project.feature_available?(:issues_analytics)
  end

  def finder_type
    IssuesFinder
  end

  def default_state
    'all'
  end

  def preload_for_collection
    nil
  end
end
