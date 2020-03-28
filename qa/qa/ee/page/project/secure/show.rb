# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project::Secure
        class Show < QA::Page::Base
          include Page::Component::SecureReport

          view 'ee/app/assets/javascripts/security_dashboard/components/security_dashboard_table.vue' do
            element :security_report_content, required: true
          end
        end
      end
    end
  end
end
