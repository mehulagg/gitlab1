# frozen_string_literal: true

require 'spec_helper'

describe Ci::CompareDastReportsService do
  let(:current_user) { project.users.take }
  let(:service) { described_class.new(project, current_user) }
  let(:project) { create(:project, :repository) }

  before do
    stub_licensed_features(container_scanning: true)
    stub_licensed_features(dast: true)
  end

  describe '#execute' do
    subject { service.execute(base_pipeline, head_pipeline) }

    context 'when head pipeline has dast reports' do
      let!(:base_pipeline) { create(:ee_ci_pipeline) }
      let!(:head_pipeline) { create(:ee_ci_pipeline, :with_dast_report, project: project) }

      it 'reports new vulnerabilities' do
        expect(subject[:status]).to eq(:parsed)
        expect(subject[:data]['added'].first['identifiers']).to include(a_hash_including('name' => 'CWE-16'))
        expect(subject[:data]['added'].count).to eq(2)
        expect(subject[:data]['existing'].count).to eq(0)
        expect(subject[:data]['fixed'].count).to eq(0)
      end
    end

    context 'when base and head pipelines have dast reports' do
      let!(:base_pipeline) { create(:ee_ci_pipeline, :with_dast_report, project: project) }
      let!(:head_pipeline) { create(:ee_ci_pipeline, :with_dast_feature_branch, project: project) }

      it 'reports status as parsed' do
        expect(subject[:status]).to eq(:parsed)
      end

      it 'populates fields based on current_user' do
        payload = subject[:data]['fixed'].first
        expect(payload['create_vulnerability_feedback_issue_path']).not_to be_empty
        expect(payload['create_vulnerability_feedback_merge_request_path']).not_to be_empty
        expect(payload['create_vulnerability_feedback_dismissal_path']).not_to be_empty
        expect(payload['create_vulnerability_feedback_issue_path']).not_to be_empty
        expect(service.current_user).to eq(current_user)
      end

      it 'reports new vulnerability' do
        expect(subject[:data]['added'].count).to eq(1)
        expect(subject[:data]['added'].first['identifiers']).to include(a_hash_including('name' => 'CWE-352'))
      end

      it 'all existing vulnerabilities should get resolved' do
        expect(subject[:data]['existing'].count).to eq(0)
      end

      it 'reports fixed dast vulnerabilities' do
        expect(subject[:data]['fixed'].count).to eq(2)
        expect(subject[:data]['fixed'].first['identifiers']).to include(a_hash_including('name' => 'CWE-16'))
      end
    end
  end
end
