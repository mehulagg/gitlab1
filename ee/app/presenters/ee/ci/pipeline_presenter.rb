# frozen_string_literal: true

module EE
  module Ci
    module PipelinePresenter
      extend ActiveSupport::Concern

      class_methods do
        extend ::Gitlab::Utils::Override

        override :failure_reasons
        def failure_reasons
          super.merge(
            activity_limit_exceeded: 'Pipeline activity limit exceeded!',
            size_limit_exceeded: 'Pipeline size limit exceeded!',
            job_activity_limit_exceeded: 'Pipeline job activity limit exceeded!'
          )
        end
      end

      def expose_security_dashboard?
        return false unless can?(current_user, :read_vulnerability, pipeline.project)

        Ci::JobArtifact::SECURITY_REPORT_FILE_TYPES.any? { |file_type| batch_lookup_report_artifact_for_file_type(file_type.to_sym) }
      end

      def degradation_threshold(file_type)
        if (job_artifact = batch_lookup_report_artifact_for_file_type(file_type)) &&
            can?(current_user, :read_build, job_artifact.job)
          job_artifact.job.degradation_threshold
        end
      end
    end
  end
end
