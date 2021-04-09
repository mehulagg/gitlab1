# frozen_string_literal: true

module EE
  module Issues
    module AfterCreateService
      extend ::Gitlab::Utils::Override

      override :execute
      def execute(issue)
        super

        add_issue_sla(issue)
      end

      private

      def add_issue_sla(issue)
        return unless issue.sla_available?

        ::IncidentManagement::Incidents::CreateSlaService.new(issue, current_user).execute
      end
    end
  end
end
