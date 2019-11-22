# frozen_string_literal: true

module EE
  module Projects
    module LogsController
      extend ActiveSupport::Concern

      prepended do
        before_action :authorize_read_pod_logs!, only: [:show]
        before_action :environment, only: [:show]
        before_action do
          push_frontend_feature_flag(:environment_logs_use_vue_ui)
        end
      end

      def show
        respond_to do |format|
          format.html do
            if environment.nil?
              render :empty_logs
            else
              render :show
            end
          end

          format.json do
            ::Gitlab::UsageCounters::PodLogs.increment(project.id)
            ::Gitlab::PollingInterval.set_header(response, interval: 3_000)

            result = PodLogsService.new(environment, params: filter_params).execute

            if result[:status] == :processing
              head :accepted
            elsif result[:status] == :success
              render json: result
            else
              render status: :bad_request, json: result
            end
          end
        end
      end

      private

      def show_params
        params.permit(:environment_name)
      end

      def filter_params
        params.permit(:container_name, :pod_name)
      end

      def environment
        @environment ||= if show_params.key?(:environment_name)
                           EnvironmentsFinder.new(project, current_user, name: show_params[:environment_name]).find.first
                         else
                           project.default_environment
                         end
      end
    end
  end
end
