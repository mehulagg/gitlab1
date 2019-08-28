# frozen_string_literal: true

require 'spec_helper'

shared_examples VulnerabilitiesActions do
  include ApiHelpers
  include VulnerableHelpers

  let(:action_params) { vulnerable_params }
  let(:user) { create(:user) }
  let(:pipeline) { create(:ci_pipeline, :success, project: vulnerable_project) }
  let(:vulnerable_project) { as_vulnerable_project(vulnerable) }

  before do
    vulnerable.add_developer(user)

    sign_in(user)
    stub_licensed_features(security_dashboard: true)
  end

  describe 'GET index.json' do
    subject { get :index, params: action_params, format: :json }

    it 'returns an ordered list of vulnerabilities' do
      critical_vulnerability = create(
        :vulnerabilities_occurrence,
        pipelines: [pipeline],
        project: vulnerable_project,
        severity: :critical
      )
      create(:vulnerabilities_occurrence, pipelines: [pipeline], project: vulnerable_project, severity: :high)

      subject

      expect(response).to have_gitlab_http_status(200)
      expect(json_response.length).to eq 2
      expect(json_response.first['id']).to be(critical_vulnerability.id)
      expect(response).to match_response_schema('vulnerabilities/occurrence_list', dir: 'ee')
    end

    context 'when a specific page is requested' do
      let(:action_params) { vulnerable_params.merge(page: 2) }

      before do
        Vulnerabilities::Occurrence.paginates_per 2

        create_list(:vulnerabilities_occurrence, 3, pipelines: [pipeline], project: vulnerable_project)

        subject
      end

      after do
        Vulnerabilities::Occurrence.paginates_per Vulnerabilities::Occurrence::OCCURRENCES_PER_PAGE
      end

      it 'returns the list of vulnerabilities that are on the requested page' do
        expect(json_response.length).to eq 1
      end
    end

    context 'when the vulnerabilities have feedback' do
      before do
        vulnerability = create(:vulnerabilities_occurrence, pipelines: [pipeline], project: vulnerable_project, report_type: :sast)
        create(:vulnerability_feedback,
                :sast,
                :issue,
                pipeline: pipeline,
                issue: create(:issue, project: vulnerable_project),
                project: vulnerable_project,
                project_fingerprint: vulnerability.project_fingerprint)
      end

      it 'avoids N+1 queries', :with_request_store do
        control_count = ActiveRecord::QueryRecorder.new { subject }

        vulnerability = create(:vulnerabilities_occurrence, pipelines: [pipeline], project: vulnerable_project, report_type: :sast)
        create(:vulnerability_feedback,
                :sast,
                :issue,
                pipeline: pipeline,
                issue: create(:issue, project: vulnerable_project),
                project: vulnerable_project,
                project_fingerprint: vulnerability.project_fingerprint)

        expect { subject }.not_to exceed_all_query_limit(control_count)
      end
    end

    context 'with multiple report types' do
      before do
        create(:vulnerabilities_occurrence, pipelines: [pipeline], project: vulnerable_project, report_type: :sast)
        create(:vulnerabilities_occurrence, pipelines: [pipeline], project: vulnerable_project, report_type: :dast)
        create(:vulnerabilities_occurrence, pipelines: [pipeline], project: vulnerable_project, report_type: :dependency_scanning)

        subject
      end

      context 'with a single report filter' do
        let(:action_params) { vulnerable_params.merge(report_type: ['sast']) }

        it 'returns a list of vulnerabilities for that reporty type only' do
          expect(json_response.length).to eq 1
          expect(json_response.map { |v| v['report_type'] }.uniq).to contain_exactly('sast')
        end
      end

      context 'with multiple report filters' do
        let(:action_params) { vulnerable_params.merge(report_type: %w[sast dependency_scanning], hide_dismissed: true) }

        it 'returns a list of vulnerabilities for all filtered upon types' do
          expect(json_response.length).to eq 2
          expect(json_response.map { |v| v['report_type'] }.uniq).to contain_exactly('sast', 'dependency_scanning')
        end
      end
    end
  end

  describe 'GET summary.json' do
    subject { get :summary, params: action_params, format: :json }

    before do
      create_list(:vulnerabilities_occurrence, 3,
        pipelines: [pipeline], project: vulnerable_project, report_type: :sast, severity: :high)
      create_list(:vulnerabilities_occurrence, 2,
        pipelines: [pipeline], project: vulnerable_project, report_type: :dependency_scanning, severity: :low)
      create_list(:vulnerabilities_occurrence, 1,
        pipelines: [pipeline], project: vulnerable_project, report_type: :dast, severity: :medium)
      create_list(:vulnerabilities_occurrence, 1,
        pipelines: [pipeline], project: vulnerable_project, report_type: :sast, severity: :medium)

      subject
    end

    it 'returns vulnerabilities counts for all report types' do
      expect(response).to have_gitlab_http_status(200)
      expect(json_response['high']).to eq(3)
      expect(json_response['low']).to eq(2)
      expect(json_response['medium']).to eq(2)
      expect(response).to match_response_schema('vulnerabilities/summary', dir: 'ee')
    end

    context 'with enabled filters' do
      let(:action_params) { vulnerable_params.merge(report_type: %w[sast dast], severity: %[high low], hide_dismissed: true) }

      it 'returns counts for filtered vulnerabilities' do
        expect(json_response['high']).to eq(3)
        expect(json_response['low']).to eq(0)
        expect(json_response['medium']).to eq(2)
      end
    end
  end
end
