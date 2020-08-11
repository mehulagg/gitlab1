# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CiConfiguration::SastParserService do
  describe '#configuration' do
    include_context 'read ci configuration for sast enabled project'

    let(:configuration) { described_class.new(project).configuration }
    let(:secure_analyzers_prefix) { configuration['global'][0] }
    let(:sast_excluded_paths) { configuration['global'][1] }
    let(:sast_analyzer_image_tag) { configuration['global'][2] }
    let(:sast_pipeline_stage) { configuration['pipeline'][0] }
    let(:sast_search_max_depth) { configuration['pipeline'][1] }

    it 'parses the configuration for SAST' do
      expect(secure_analyzers_prefix['default_value']).to eql('registry.gitlab.com/gitlab-org/security-products/analyzers')
      expect(sast_excluded_paths['default_value']).to eql('spec, test, tests, tmp')
      expect(sast_analyzer_image_tag['default_value']).to eql('2')
      expect(sast_pipeline_stage['default_value']).to eql('test')
      expect(sast_search_max_depth['default_value']).to eql('4')
    end

    context 'while populating current values of the entities' do
      context 'when .gitlab-ci.yml is present' do
        before do
          allow(project).to receive(:gitlab_ci_present?).and_return(true)
        end

        it 'populates the current values from the file' do
          expect(secure_analyzers_prefix['value']).to eql('registry.gitlab.com/gitlab-org/security-products/analyzers2')
          expect(sast_excluded_paths['value']).to eql('spec, executables')
          expect(sast_analyzer_image_tag['value']).to eql('2')
          expect(sast_pipeline_stage['value']).to eql('our_custom_security_stage')
          expect(sast_search_max_depth['value']).to eql('8')
        end
      end

      context 'when .gitlab-ci.yml is absent' do
        it 'assigns current values to nil' do
          expect(secure_analyzers_prefix['value']).to eql("")
          expect(sast_excluded_paths['value']).to eql("")
          expect(sast_analyzer_image_tag['value']).to eql("")
        end
      end
    end
  end
end
