require 'spec_helper'

describe Ci::Pipeline do
  let(:user) { create(:user) }
  set(:project) { create(:project) }

  let(:pipeline) do
    create(:ci_empty_pipeline, status: :created, project: project)
  end

  it { is_expected.to have_one(:chat_data) }
  it { is_expected.to have_many(:job_artifacts).through(:builds) }
  it { is_expected.to have_many(:vulnerabilities).through(:vulnerabilities_occurrence_pipelines).class_name('Vulnerabilities::Occurrence') }
  it { is_expected.to have_many(:vulnerabilities_occurrence_pipelines).class_name('Vulnerabilities::OccurrencePipeline') }

  describe '.failure_reasons' do
    it 'contains failure reasons about exceeded limits' do
      expect(described_class.failure_reasons)
        .to include 'activity_limit_exceeded', 'size_limit_exceeded'
    end
  end

  PIPELINE_ARTIFACTS_METHODS = [
    { method: :performance_artifact, options: [Ci::Build::PERFORMANCE_FILE, 'performance'] },
    { method: :license_management_artifact, options: [Ci::Build::LICENSE_MANAGEMENT_FILE, 'license_management'] }
  ].freeze

  PIPELINE_ARTIFACTS_METHODS.each do |method_test|
    method, options = method_test.values_at(:method, :options)
    describe method.to_s do
      context 'has corresponding job' do
        let!(:build) do
          filename, name = options

          create(
            :ci_build,
            :artifacts,
            name: name,
            pipeline: pipeline,
            options: {
              artifacts: {
                paths: [filename]
              }
            }
          )
        end

        it { expect(pipeline.send(method)).to eq(build) }
      end

      context 'no corresponding job' do
        before do
          create(:ci_build, pipeline: pipeline)
        end

        it { expect(pipeline.send(method)).to be_nil }
      end
    end
  end

  %w(performance license_management).each do |type|
    method = "has_#{type}_data?"

    describe "##{method}" do
      let(:artifact) { double(success?: true) }

      before do
        allow(pipeline).to receive(:"#{type}_artifact").and_return(artifact)
      end

      it { expect(pipeline.send(method.to_sym)).to be_truthy }
    end
  end

  %w(performance license_management).each do |type|
    method = "expose_#{type}_data?"

    describe "##{method}" do
      before do
        allow(pipeline).to receive(:"has_#{type}_data?").and_return(true)
        allow(pipeline.project).to receive(:feature_available?).and_return(true)
      end

      it { expect(pipeline.send(method.to_sym)).to be_truthy }
    end
  end

  describe '#with_legacy_security_reports scope' do
    let(:pipeline_1) { create(:ci_pipeline_without_jobs, project: project) }
    let(:pipeline_2) { create(:ci_pipeline_without_jobs, project: project) }
    let(:pipeline_3) { create(:ci_pipeline_without_jobs, project: project) }
    let(:pipeline_4) { create(:ci_pipeline_without_jobs, project: project) }
    let(:pipeline_5) { create(:ci_pipeline_without_jobs, project: project) }

    before do
      create(
        :ci_build,
        :success,
        :artifacts,
        name: 'sast',
        pipeline: pipeline_1,
        options: {
          artifacts: {
            paths: [Ci::JobArtifact::DEFAULT_FILE_NAMES[:sast]]
          }
        }
      )
      create(
        :ci_build,
        :success,
        :artifacts,
        name: 'dependency_scanning',
        pipeline: pipeline_2,
        options: {
          artifacts: {
            paths: [Ci::JobArtifact::DEFAULT_FILE_NAMES[:dependency_scanning]]
          }
        }
      )
      create(
        :ci_build,
        :success,
        :artifacts,
        name: 'container_scanning',
        pipeline: pipeline_3,
        options: {
          artifacts: {
            paths: [Ci::JobArtifact::DEFAULT_FILE_NAMES[:container_scanning]]
          }
        }
      )
      create(
        :ci_build,
        :success,
        :artifacts,
        name: 'dast',
        pipeline: pipeline_4,
        options: {
          artifacts: {
            paths: [Ci::JobArtifact::DEFAULT_FILE_NAMES[:dast]]
          }
        }
      )
      create(
        :ci_build,
        :success,
        :artifacts,
        name: 'foobar',
        pipeline: pipeline_5
      )
    end

    it "returns pipeline with security reports" do
      expect(described_class.with_legacy_security_reports).to eq([pipeline_1, pipeline_2, pipeline_3, pipeline_4])
    end
  end

  shared_examples 'unlicensed report type' do
    context 'when there is no licensed feature for artifact file type' do
      it 'returns the artifact' do
        expect(subject).to eq(expected)
      end
    end
  end

  shared_examples 'licensed report type' do |feature|
    context 'when licensed features is NOT available' do
      it 'returns nil' do
        allow(pipeline.project).to receive(:feature_available?)
          .with(feature).and_return(false)

        expect(subject).to be_nil
      end
    end

    context 'when licensed feature is available' do
      it 'returns the artifact' do
        allow(pipeline.project).to receive(:feature_available?)
          .with(feature).and_return(true)

        expect(subject).to eq(expected)
      end
    end
  end

  shared_examples 'multi-licensed report type' do |features|
    context 'when NONE of the licensed features are available' do
      it 'returns nil' do
        features.each do |feature|
          allow(pipeline.project).to receive(:feature_available?)
            .with(feature).and_return(false)
        end

        expect(subject).to be_nil
      end
    end

    context 'when at least one licensed feature is available' do
      features.each do |feature|
        it 'returns the artifact' do
          allow(pipeline.project).to receive(:feature_available?)
              .with(feature).and_return(true)

          features.reject { |f| f == feature }.each do |disabled_feature|
            allow(pipeline.project).to receive(:feature_available?)
              .with(disabled_feature).and_return(true)
          end

          expect(subject).to eq(expected)
        end
      end
    end
  end

  describe '#report_artifact_for_file_type' do
    let!(:build) { create(:ci_build, pipeline: pipeline) }

    let!(:artifact) do
      create(:ci_job_artifact,
        job: build,
        file_type: file_type,
        file_format: ::Ci::JobArtifact::TYPE_AND_FORMAT_PAIRS[file_type])
    end

    subject { pipeline.report_artifact_for_file_type(file_type) }

    described_class::REPORT_LICENSED_FEATURES.each do |file_type, licensed_features|
      context "for file_type: #{file_type}" do
        let(:file_type) { file_type }
        let(:expected) { artifact }

        if licensed_features.nil?
          it_behaves_like 'unlicensed report type'
        elsif licensed_features.size == 1
          it_behaves_like 'licensed report type', licensed_features.first
        else
          it_behaves_like 'multi-licensed report type', licensed_features
        end
      end
    end
  end

  describe '#legacy_report_artifact_for_file_type' do
    let(:build_name) { ::EE::Ci::Pipeline::LEGACY_REPORT_FORMATS[file_type][:names].first }
    let(:artifact_path) { ::EE::Ci::Pipeline::LEGACY_REPORT_FORMATS[file_type][:files].first }

    let!(:build) do
      create(
        :ci_build,
        :success,
        :artifacts,
        name: build_name,
        pipeline: pipeline,
        options: {
          artifacts: {
            paths: [artifact_path]
          }
        }
      )
    end

    subject { pipeline.legacy_report_artifact_for_file_type(file_type) }

    described_class::REPORT_LICENSED_FEATURES.each do |file_type, licensed_features|
      context "for file_type: #{file_type}" do
        let(:file_type) { file_type }
        let(:expected) { OpenStruct.new(build: build, path: artifact_path) }

        if licensed_features.nil?
          it_behaves_like 'unlicensed report type'
        elsif licensed_features.size == 1
          it_behaves_like 'licensed report type', licensed_features.first
        else
          it_behaves_like 'multi-licensed report type', licensed_features
        end
      end
    end
  end

  context 'performance' do
    def create_build(job_name, filename)
      create(
        :ci_build,
        :artifacts,
        name: job_name,
        pipeline: pipeline,
        options: {
          artifacts: {
            paths: [filename]
          }
        }
      )
    end

    it 'does not perform extra queries when calling pipeline artifacts methods after the first' do
      create_build('performance', 'performance.json')
      create_build('license_management', 'gl-license-management-report.json')

      pipeline.performance_artifact

      expect { pipeline.license_management_artifact }.not_to exceed_query_limit(0)
    end
  end

  describe '#has_security_reports?' do
    subject { pipeline.has_security_reports? }

    context 'when pipeline has builds with security reports' do
      before do
        create(:ee_ci_build, :security_reports, pipeline: pipeline, project: project)
      end

      context 'when pipeline status is running' do
        let(:pipeline) { create(:ci_pipeline, :running, project: project) }

        it { is_expected.to be_falsey }
      end

      context 'when pipeline status is success' do
        let(:pipeline) { create(:ci_pipeline, :success, project: project) }

        it { is_expected.to be_truthy }
      end
    end

    context 'when pipeline does not have builds with security reports' do
      before do
        create(:ci_build, :artifacts, pipeline: pipeline, project: project)
      end

      let(:pipeline) { create(:ci_pipeline, :success, project: project) }

      it { is_expected.to be_falsey }
    end

    context 'when retried build has security reports' do
      before do
        create(:ee_ci_build, :retried, :security_reports, pipeline: pipeline, project: project)
      end

      let(:pipeline) { create(:ci_pipeline, :success, project: project) }

      it { is_expected.to be_falsey }
    end
  end

  describe '#security_reports' do
    subject { pipeline.security_reports }

    before do
      stub_licensed_features(sast: true)
    end

    context 'when pipeline has multiple builds with security reports' do
      let!(:build_sast_1) { create(:ci_build, :success, name: 'sast_1', pipeline: pipeline, project: project) }
      let!(:build_sast_2) { create(:ci_build, :success, name: 'sast_2', pipeline: pipeline, project: project) }

      before do
        create(:ee_ci_job_artifact, :sast, job: build_sast_1, project: project)
        create(:ee_ci_job_artifact, :sast, job: build_sast_2, project: project)
      end

      it 'returns security reports with collected data grouped as expected' do
        expect(subject.reports.keys).to eq(%w(sast))
        expect(subject.get_report('sast').occurrences.size).to eq(6)
      end

      context 'when builds are retried' do
        let!(:build_sast_1) { create(:ci_build, :retried, name: 'sast_1', pipeline: pipeline, project: project) }
        let!(:build_sast_2) { create(:ci_build, :retried, name: 'sast_2', pipeline: pipeline, project: project) }

        it 'does not take retried builds into account' do
          expect(subject.reports).to eq({})
        end
      end
    end

    context 'when pipeline does not have any builds with security reports' do
      it 'returns empty security reports' do
        expect(subject.reports).to eq({})
      end
    end
  end

  describe 'Store security reports worker' do
    using RSpec::Parameterized::TableSyntax

    where(:state, :transition) do
      :success | :succeed
      :failed | :drop
      :skipped | :skip
      :cancelled | :cancel
    end

    with_them do
      context 'when pipeline has security reports and ref is the default branch of project' do
        let(:default_branch) { pipeline.ref }

        before do
          create(:ee_ci_build, :security_reports, pipeline: pipeline, project: project)
          allow(project).to receive(:default_branch) { default_branch }
        end

        context "when transitioning to #{params[:state]}" do
          it 'schedules store security report worker' do
            expect(StoreSecurityReportsWorker).to receive(:perform_async).with(pipeline.id)

            pipeline.update!(status_event: transition)
          end
        end
      end

      context 'when pipeline does NOT have security reports' do
        context "when transitioning to #{params[:state]}" do
          it 'does NOT schedule store security report worker' do
            expect(StoreSecurityReportsWorker).not_to receive(:perform_async).with(pipeline.id)

            pipeline.update!(status_event: transition)
          end
        end
      end

      context "when pipeline ref is not the project's default branch" do
        let(:default_branch) { 'another_branch' }

        before do
          stub_licensed_features(sast: true)
          allow(project).to receive(:default_branch) { default_branch }
        end

        context "when transitioning to #{params[:state]}" do
          it 'does NOT schedule store security report worker' do
            expect(StoreSecurityReportsWorker).not_to receive(:perform_async).with(pipeline.id)

            pipeline.update!(status_event: transition)
          end
        end
      end
    end
  end

  describe '#has_license_management_reports?' do
    subject { pipeline.has_license_management_reports? }

    context 'when pipeline has builds with license_management reports' do
      before do
        create(:ee_ci_build, :license_management_report, pipeline: pipeline, project: project)
      end

      context 'when pipeline status is running' do
        let(:pipeline) { create(:ci_pipeline, :running, project: project) }

        it { is_expected.to be_falsey }
      end

      context 'when pipeline status is success' do
        let(:pipeline) { create(:ci_pipeline, :success, project: project) }

        it { is_expected.to be_truthy }
      end
    end

    context 'when pipeline does not have builds with license_management reports' do
      before do
        create(:ci_build, :artifacts, pipeline: pipeline, project: project)
      end

      let(:pipeline) { create(:ci_pipeline, :success, project: project) }

      it { is_expected.to be_falsey }
    end

    context 'when retried build has license management reports' do
      before do
        create(:ee_ci_build, :retried, :license_management_report, pipeline: pipeline, project: project)
      end

      let(:pipeline) { create(:ci_pipeline, :success, project: project) }

      it { is_expected.to be_falsey }
    end
  end

  describe '#license_management_reports' do
    subject { pipeline.license_management_report }

    context 'when pipeline has multiple builds with license management reports' do
      let!(:build_1) { create(:ci_build, :success, name: 'license_management', pipeline: pipeline, project: project) }
      let!(:build_2) { create(:ci_build, :success, name: 'license_management2', pipeline: pipeline, project: project) }

      before do
        create(:ee_ci_job_artifact, :license_management_report, job: build_1, project: project)
        create(:ee_ci_job_artifact, :license_management_report_2, job: build_2, project: project)
      end

      it 'returns a license management report with collected data' do
        expect(subject.licenses.count).to be(5)
        expect(subject.licenses.any? { |license| license.name == 'WTFPL' } ).to be_truthy
        expect(subject.licenses.any? { |license| license.name == 'MIT' } ).to be_truthy
      end

      context 'when builds are retried' do
        let!(:build_1) { create(:ci_build, :retried, :success, name: 'license_management', pipeline: pipeline, project: project) }
        let!(:build_2) { create(:ci_build, :retried, :success, name: 'license_management2', pipeline: pipeline, project: project) }

        it 'does not take retried builds into account' do
          expect(subject.licenses.count).to be(0)
        end
      end
    end

    context 'when pipeline does not have any builds with license management reports' do
      it 'returns an empty license management report' do
        expect(subject.licenses.count).to be(0)
      end
    end
  end
end
