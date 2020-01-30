# frozen_string_literal: true

module ErrorTracking
  class IssueDetailsService < ErrorTracking::BaseService
    private

    def perform
      response = project_error_tracking_setting.issue_details(issue_id: params[:issue_id])

      compose_response(response)
    end

    def parse_response(response)
      { issue: response[:issue] }
    end
  end
end
