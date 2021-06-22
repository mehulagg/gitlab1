# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::StoreReportsService do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, namespace: group) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project, user: user) }

  describe '#execute' do
    subject(:execute_service_object) { described_class.new(pipeline).execute }

    context 'when there are reports' do
      before do
        stub_licensed_features(sast: true, dependency_scanning: true, container_scanning: true, security_dashboard: true)
        create(:ee_ci_build, :sast, pipeline: pipeline)
        create(:ee_ci_build, :dependency_scanning, pipeline: pipeline)
        create(:ee_ci_build, :container_scanning, pipeline: pipeline)
        project.add_developer(user)
        allow(pipeline).to receive(:user).and_return(user)
      end

      it 'initializes and execute a StoreReportService for each report' do
        expect(Security::StoreReportService).to receive(:new)
          .exactly(3).times.with(pipeline, instance_of(::Gitlab::Ci::Reports::Security::Report))
          .and_wrap_original do |method, *original_args|
            method.call(*original_args).tap do |store_service|
              expect(store_service).to receive(:execute).once.and_call_original
            end
          end

        execute_service_object
      end

      it 'marks the project as vulnerable' do
        expect { execute_service_object }.to change { project.reload.project_setting.has_vulnerabilities }.from(false).to(true)
      end

      it 'updates the `latest_pipeline_id` attribute of the associated `vulnerability_statistic` record' do
        expect { execute_service_object }.to change { project.reload.vulnerability_statistic&.latest_pipeline_id }.from(nil).to(pipeline.id)
      end

      context 'when StoreReportService returns an error for a report' do
        let(:reports) { Gitlab::Ci::Reports::Security::Reports.new(pipeline) }
        let(:sast_report) { reports.get_report('sast', sast_artifact) }
        let(:dast_report) { reports.get_report('dast', dast_artifact) }
        let(:success) { { status: :success } }
        let(:error) { { status: :error, message: "something went wrong" } }
        let(:sast_artifact) { create(:ee_ci_job_artifact, :sast) }
        let(:dast_artifact) { create(:ee_ci_job_artifact, :dast) }

        before do
          allow(pipeline).to receive(:security_reports).and_return(reports)
        end

        it 'returns the errors after having processed all reports' do
          expect_next_instance_of(Security::StoreReportService, pipeline, sast_report) do |store_service|
            expect(store_service).to receive(:execute).and_return(error)
          end
          expect_next_instance_of(Security::StoreReportService, pipeline, dast_report) do |store_service|
            expect(store_service).to receive(:execute).and_return(success)
          end

          is_expected.to eq(error)
        end
      end

      context 'event tracking' do
        let(:reports) { Gitlab::Ci::Reports::Security::Reports.new(pipeline) }
        let(:dast_artifact) { create(:ee_ci_job_artifact, :dast) }
        let(:success) { { status: :success } }
        let(:scan) { nil }

        let(:dast_report) do
          report = reports.get_report('dast', dast_artifact)
          report.scan = scan
          report
        end

        before do
          allow(pipeline).to receive(:security_reports).and_return(reports)

          expect_next_instance_of(Security::StoreReportService, pipeline, dast_report) do |store_service|
            expect(store_service).to receive(:execute).and_return(success)
          end
        end

        context 'report has scan metadata' do
          let(:scan) do
            ::Gitlab::Ci::Reports::Security::Scan.new({ type: 'dast',
                                                        status: 'success',
                                                        start_time: '2021-06-11T07:26:17',
                                                        end_time: '2021-06-11T07:27:50' }.stringify_keys)
          end

          it 'tracks the scan event', :snowplow do
            execute_service_object

            expect_snowplow_event(
              category: 'secure::scan',
              action: 'scan',
              end_time: '2021-06-11T07:27:50',
              project: project.id,
              scan_type: 'dast',
              start_time: '2021-06-11T07:26:17',
              status: 'success',
              triggered_by: user.id
            )
          end
        end

        context 'report has no scan metadata' do
          it 'tracks the scan event', :snowplow do
            execute_service_object

            expect_snowplow_event(
              category: 'secure::scan',
              action: 'scan',
              end_time: nil,
              project: project.id,
              scan_type: 'dast',
              start_time: nil,
              status: nil,
              triggered_by: user.id
            )
          end
        end
      end
    end
  end
end
