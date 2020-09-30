# frozen_string_literal: true

class Projects::AlertManagementController < Projects::ApplicationController
  before_action :authorize_read_alert_management_alert!

  def index
  end

  def details
    @alert_id = params[:id]
    push_frontend_feature_flag(:enable_environment_path_in_alert_details, @project)
  end
end
