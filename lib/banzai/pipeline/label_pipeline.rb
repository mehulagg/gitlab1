# frozen_string_literal: true

module Banzai
  module Pipeline
    class LabelPipeline < BasePipeline
      def self.filters
        @filters ||= FilterArray[
          Filter::References::SanitizationFilter,
          Filter::References::LabelReferenceFilter
        ]
      end
    end
  end
end
