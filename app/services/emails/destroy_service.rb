# frozen_string_literal: true

module Emails
  class DestroyService < ::Emails::BaseService
    prepend ::EE::Emails::DestroyService # rubocop: disable Cop/InjectEnterpriseEditionModule

    def execute(email)
      email.destroy && update_secondary_emails!
    end

    private

    def update_secondary_emails!
      result = ::Users::UpdateService.new(@current_user, user: @user).execute do |user|
        user.update_secondary_emails!
      end

      result[:status] == 'success'
    end
  end
end
