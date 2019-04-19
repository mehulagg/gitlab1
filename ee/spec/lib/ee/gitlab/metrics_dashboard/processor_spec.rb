# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::MetricsDashboard::Processor do
  let(:project) { build(:project) }
  let(:environment) { alert.environment }
  let(:dashboard_yml) { YAML.load_file('spec/fixtures/lib/gitlab/metrics_dashboard/sample_dashboard.yml') }

  describe 'process' do
    let(:process_params) { [dashboard_yml, project, environment] }
    let(:dashboard) { described_class.new(*process_params).process }

    context 'when the dashboard references persisted metrics with alerts' do
      let!(:alert) { create(:prometheus_alert, project: project, prometheus_metric: persisted_metric) }

      shared_examples_for 'has saved alerts' do
        it 'includes an alert path' do
          target_metric = all_metrics.find { |metric| metric[:metric_id] == persisted_metric.id }

          STDOUT.puts "!!!!!!!!!!!!!!!!!!!!"
          # STDERR.puts "!!!!!!!!!!!!!!!!!!!!"
          STDOUT.puts PrometheusAlert.all.inspect
          $stdout.puts target_metric

          # $stderr.puts PrometheusAlert.all
          # $stderr.puts target_metric

          Rails.logger.error("PrometheusAlert: #{PrometheusAlert.all}")
          Rails.logger.error("target_metric: #{target_metric}")
          Rails.logger.info("PrometheusAlert: #{PrometheusAlert.all}")
          Rails.logger.info("target_metric: #{target_metric}")

          expect(target_metric).to be_a Hash
          expect(target_metric).to include(:alert_path)
          expect(target_metric[:alert_path]).to include(
            project.path,
            persisted_metric.id.to_s,
            environment.id.to_s
          )
        end
      end

      context 'that are shared across projects' do
        let!(:persisted_metric) { create(:prometheus_metric, :common, identifier: 'metric_a1') }

        it_behaves_like 'has saved alerts'
      end

      context 'when the project has associated metrics' do
        let!(:persisted_metric) { create(:prometheus_metric, project: project, group: :business) }

        it_behaves_like 'has saved alerts'
      end
    end
  end

  private

  def all_metrics
    dashboard[:panel_groups].map do |group|
      group[:panels].map { |panel| panel[:metrics] }
    end.flatten
  end
end
