# frozen_string_literal: true

class Projects::AlertManagementController < Projects::ApplicationController
  before_action :authorize_read_alert_management_alert!

  def index
  end

  def details
    @alert_id = params[:id]
  end
end
