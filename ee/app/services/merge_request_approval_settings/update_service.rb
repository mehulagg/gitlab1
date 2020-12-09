# frozen_string_literal: true

module MergeRequestApprovalSettings
  class UpdateService < BaseContainerService
    def execute
      return ServiceResponse.error(message: _('Insufficient permissions')) unless allowed?

      setting = MergeRequestApprovalSetting.find_or_initialize_by_namespace(container)
      setting.assign_attributes(params)

      if setting.save
        ServiceResponse.success(payload: setting)
      else
        ServiceResponse.error(message: setting.errors.messages)
      end
    end

    private

    def allowed?
      can?(current_user, :admin_merge_request_approval_settings, container)
    end
  end
end
