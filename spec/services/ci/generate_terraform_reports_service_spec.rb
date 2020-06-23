# frozen_string_literal: true

require 'spec_helper'

describe Ci::GenerateTerraformReportsService do
  let_it_be(:project) { create(:project, :repository) }

  describe '#execute' do
    let_it_be(:merge_request) { create(:merge_request, :with_terraform_reports, source_project: project) }

    subject { described_class.new(project, nil, id: merge_request.id) }

    context 'when head pipeline has terraform reports' do
      it 'returns status and data' do
        pipeline = merge_request.head_pipeline
        result = subject.execute(nil, pipeline)

        pipeline.builds.each do |build|
          expect(result).to match(
            status: :parsed,
            data: match(
              a_hash_including(build.id.to_s => hash_including(
                'create' => 0,
                'delete' => 0,
                'update' => 1,
                'job_name' => build.options.dig(:artifacts, :name).to_s
              ))
            ),
            key: an_instance_of(Array)
          )
        end
      end
    end

    context 'when head pipeline has corrupted terraform reports' do
      it 'returns a report with error messages' do
        build = create(:ci_build, pipeline: merge_request.head_pipeline, project: project)
        create(:ci_job_artifact, :terraform_with_corrupted_data, job: build, project: project)

        result = subject.execute(nil, merge_request.head_pipeline)

        expect(result).to match(
          status: :parsed,
          data: match(
            a_hash_including(build.id.to_s => hash_including(
              'tf_report_error' => :invalid_json_format
            ))
          ),
          key: an_instance_of(Array)
        )
      end
    end

    context 'when head pipeline is corrupted' do
      it 'returns status and error message' do
        result = subject.execute(nil, nil)

        expect(result).to match(
          a_hash_including(
            status: :error,
            status_reason: 'An error occurred while fetching terraform reports.'
          )
        )
      end
    end
  end

  describe '#latest?' do
    let_it_be(:head_pipeline) { create(:ci_pipeline, :with_test_reports, project: project) }

    subject { described_class.new(project) }

    it 'returns true when cache key is latest' do
      cache_key = subject.send(:key, nil, head_pipeline)

      result = subject.latest?(nil, head_pipeline, key: cache_key)

      expect(result).to eq(true)
    end

    it 'returns false when cache key is outdated' do
      cache_key = subject.send(:key, nil, head_pipeline)
      head_pipeline.update_column(:updated_at, 10.minutes.ago)

      result = subject.latest?(nil, head_pipeline, key: cache_key)

      expect(result).to eq(false)
    end

    it 'returns false when cache key is nil' do
      result = subject.latest?(nil, head_pipeline, key: nil)

      expect(result).to eq(false)
    end
  end
end
