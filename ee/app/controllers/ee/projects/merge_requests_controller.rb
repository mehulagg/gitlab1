# frozen_string_literal: true

module EE
  module Projects
    module MergeRequestsController
      extend ActiveSupport::Concern

      prepended do
        include DescriptionDiffActions

        before_action only: [:show] do
          push_frontend_feature_flag(:anonymous_visual_review_feedback)
        end

        before_action :whitelist_query_limiting_ee_merge, only: [:merge]
        before_action :whitelist_query_limiting_ee_show, only: [:show]
        before_action :authorize_read_pipeline!, only: [:container_scanning_reports, :dependency_scanning_reports,
                                                        :license_scanning_reports,
                                                        :sast_reports, :secret_detection_reports, :dast_reports, :metrics_reports]

        feature_category :container_scanning, only: [:container_scanning_reports]
        feature_category :dependency_scanning, only: [:dependency_scanning_reports]
        feature_category :license_compliance, only: [:license_scanning_reports]
        feature_category :static_application_security_testing, only: [:sast_reports]
        feature_category :secret_detection, only: [:secret_detection_reports]
        feature_category :dynamic_application_security_testing, only: [:dast_reports]
        feature_category :metrics, only: [:metrics_reports]
      end

      def license_scanning_reports
        reports_response(merge_request.compare_license_scanning_reports(current_user))
      end

      def container_scanning_reports
        reports_response(merge_request.compare_container_scanning_reports(current_user))
      end

      def dependency_scanning_reports
        reports_response(merge_request.compare_dependency_scanning_reports(current_user))
      end

      def sast_reports
        reports_response(merge_request.compare_sast_reports(current_user))
      end

      def secret_detection_reports
        reports_response(merge_request.compare_secret_detection_reports(current_user))
      end

      def dast_reports
        reports_response(merge_request.compare_dast_reports(current_user))
      end

      def metrics_reports
        reports_response(merge_request.compare_metrics_reports)
      end

      private

      # rubocop:disable Gitlab/ModuleWithInstanceVariables
      def merge_access_check
        super_result = super

        return super_result if super_result
        return render_404 unless @merge_request.approved?
      end
      # rubocop:enable Gitlab/ModuleWithInstanceVariables

      def whitelist_query_limiting_ee_merge
        ::Gitlab::QueryLimiting.whitelist('https://gitlab.com/gitlab-org/gitlab/issues/4792')
      end

      def whitelist_query_limiting_ee_show
        ::Gitlab::QueryLimiting.whitelist('https://gitlab.com/gitlab-org/gitlab/issues/4793')
      end
    end
  end
end
