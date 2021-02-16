# frozen_string_literal: true

class Groups::Analytics::CoverageReportsController < Groups::Analytics::ApplicationController
  feature_category :code_testing

  COVERAGE_PARAM = 'coverage'.freeze

  before_action :load_group
  before_action -> { check_feature_availability!(:group_coverage_reports) }

  def index
    respond_to do |format|
      format.csv do
        track_event(:download_code_coverage_csv, **download_tracker_params)
        send_data(render_csv(report_results), type: 'text/csv; charset=utf-8')
      end
    end
  end

  private

  def render_csv(collection)
    CsvBuilders::SingleBatch.new(
      collection,
      {
        date: 'date',
        group_name: 'group_name',
        project_name: -> (record) { record.project.name },
        COVERAGE_PARAM => -> (record) { record.data[COVERAGE_PARAM] }
      }
    ).render
  end

  def report_results
    ::Ci::DailyBuildGroupReportResultsFinder.new(
      params: finder_params,
      current_user: current_user
    ).execute
  end

  def finder_params
    {
      group: @group,
      coverage: true,
      start_date: Date.parse(params.require(:start_date)),
      end_date: Date.parse(params.require(:end_date)),
      ref_path: params[:ref_path],
      sort: true
    }
  end

  def download_tracker_params
    {
      label: 'group_id',
      value: @group.id
    }
  end
end
