# frozen_string_literal: true

module Gitlab
  module Ci
    module Reports
      class TerraformReports
        attr_reader :plans

        def initialize
          @plans = {}
        end

        def pick(keys)
          terraform_plans = plans.select do |key|
            keys.include?(key)
          end

          { plans: terraform_plans }
        end

        def add_plan(name, plan)
          plans[name] = plan
        end
      end
    end
  end
end
