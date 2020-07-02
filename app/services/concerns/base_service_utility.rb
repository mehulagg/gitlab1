# frozen_string_literal: true

module BaseServiceUtility
  extend ActiveSupport::Concern
  include Gitlab::Allowable

  ### Convenience service methods

  def notification_service
    NotificationService.new
  end

  def event_service
    EventCreateService.new
  end

  def todo_service
    TodoService.new
  end

  def system_hook_service
    SystemHooksService.new
  end

  # Logging

  def log_info(message)
    Gitlab::AppLogger.info message
  end

  def log_error(message)
    Gitlab::AppLogger.error message
  end

  # Add an error to the specified model for restricted visibility levels
  def deny_visibility_level(model, denied_visibility_level = nil)
    denied_visibility_level ||= model.visibility_level

    level_name = Gitlab::VisibilityLevel.level_name(denied_visibility_level).downcase

    model.errors.add(:visibility_level, "#{level_name} has been restricted by your GitLab administrator")
  end

  def visibility_level
    params[:visibility].is_a?(String) ? Gitlab::VisibilityLevel.level_value(params[:visibility]) : params[:visibility_level]
  end

  private

  # Return a Hashlike `ServiceResponse` with an `error` status
  #
  # message     - Error message to include in the Hash
  # http_status - Optional HTTP status code override (default: nil)
  # pass_back   - Additional attributes to be included in the resulting Hash
  def error(message, http_status = nil, pass_back: {})
    ServiceResponse.error(
      message: message,
      http_status: http_status,
      payload: pass_back
    )
  end

  # Return a Hashlike `ServiceResponse` with a `success` status
  #
  # pass_back - Additional attributes to be included in the resulting Hash
  def success(pass_back = {})
    ServiceResponse.success(
      message: pass_back.delete(:message),
      http_status: pass_back.delete(:http_status) || :ok,
      payload: pass_back
    )
  end
end
