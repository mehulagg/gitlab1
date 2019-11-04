# frozen_string_literal: true

require 'fast_spec_helper'
require 'rspec-parameterized'

describe Gitlab::SidekiqMiddleware::Metrics do
  using RSpec::Parameterized::TableSyntax

  let(:middleware) { described_class.new }
  let(:concurrency_metric) { double('concurrency metric') }

  let(:queue_duration_seconds) { double('queue duration seconds metric') }
  let(:completion_seconds_metric) { double('completion seconds metric') }
  let(:user_execution_seconds_metric) { double('user execution seconds metric') }
  let(:failed_total_metric) { double('failed total metric') }
  let(:retried_total_metric) { double('retried total metric') }
  let(:running_jobs_metric) { double('running jobs metric') }

  before do
    allow(Gitlab::Metrics).to receive(:histogram).with(:sidekiq_jobs_queue_duration_seconds, anything, anything, anything).and_return(queue_duration_seconds)
    allow(Gitlab::Metrics).to receive(:histogram).with(:sidekiq_jobs_completion_seconds, anything, anything, anything).and_return(completion_seconds_metric)
    allow(Gitlab::Metrics).to receive(:histogram).with(:sidekiq_jobs_cpu_seconds, anything, anything, anything).and_return(user_execution_seconds_metric)
    allow(Gitlab::Metrics).to receive(:counter).with(:sidekiq_jobs_failed_total, anything).and_return(failed_total_metric)
    allow(Gitlab::Metrics).to receive(:counter).with(:sidekiq_jobs_retried_total, anything).and_return(retried_total_metric)
    allow(Gitlab::Metrics).to receive(:gauge).with(:sidekiq_running_jobs, anything, {}, :all).and_return(running_jobs_metric)
    allow(Gitlab::Metrics).to receive(:gauge).with(:sidekiq_concurrency, anything, {}, :all).and_return(concurrency_metric)

    allow(concurrency_metric).to receive(:set)
  end

  describe '#initialize' do
    it 'sets general metrics' do
      expect(concurrency_metric).to receive(:set).with({}, Sidekiq.options[:concurrency].to_i)

      middleware
    end
  end

  it 'ignore user execution when measured 0' do
    allow(completion_seconds_metric).to receive(:observe)

    expect(user_execution_seconds_metric).not_to receive(:observe)
  end

  describe '#call' do
    let(:worker) { double(:worker) }

    let(:job) { {} }
    let(:job_status) { :done }
    let(:labels) { { queue: :test } }
    let(:labels_with_job_status) { labels.merge(job_status: job_status) }

    let(:thread_cputime_before) { 1 }
    let(:thread_cputime_after) { 2 }
    let(:thread_cputime_duration) { thread_cputime_after - thread_cputime_before }

    let(:monotonic_time_before) { 11 }
    let(:monotonic_time_after) { 20 }
    let(:monotonic_time_duration) { monotonic_time_after - monotonic_time_before }

    let(:queue_duration_for_job) { 0.01 }

    where(:worker_has_attributes, :worker_is_latency_sensitive, :worker_has_external_dependencies, :worker_feature_category, :worker_resource_boundary, :labels) do
      false | false | false | nil             | nil      | { queue: :test }
      true  | false | false | nil             | nil      | { queue: :test }
      true  | true  | false | nil             | nil      | { queue: :test, latency_sensitive: true }
      true  | false | true  | nil             | nil      | { queue: :test, external_deps: true }
      true  | false | false | :authentication | nil      | { queue: :test, feat_cat: :authentication }
      true  | false | false | nil             | :cpu     | { queue: :test, boundary: :cpu }
      true  | false | false | nil             | :memory  | { queue: :test, boundary: :memory }
      true  | false | false | nil             | :unknown | { queue: :test }
      true  | true  | true  | :authentication | :cpu     | { queue: :test, latency_sensitive: true, external_deps: true, feat_cat: :authentication, boundary: :cpu }
    end

    with_them do
      before do
        allow(middleware).to receive(:get_thread_cputime).and_return(thread_cputime_before, thread_cputime_after)
        allow(Gitlab::Metrics::System).to receive(:monotonic_time).and_return(monotonic_time_before, monotonic_time_after)
        allow(Gitlab::InstrumentationHelper).to receive(:queue_duration_for_job).with(job).and_return(queue_duration_for_job)

        # Attributes
        allow(worker).to receive(:include?).with(WorkerAttributes).and_return(worker_has_attributes)
        allow(worker).to receive(:latency_sensitive_worker?).and_return(worker_is_latency_sensitive)
        allow(worker).to receive(:worker_has_external_dependencies?).and_return(worker_has_external_dependencies)
        allow(worker).to receive(:get_worker_resource_boundary).and_return(worker_resource_boundary)
        allow(worker).to receive(:get_feature_category).and_return(worker_feature_category)

        expect(running_jobs_metric).to receive(:increment).with(labels, 1)
        expect(running_jobs_metric).to receive(:increment).with(labels, -1)

        expect(queue_duration_seconds).to receive(:observe).with(labels, queue_duration_for_job) if queue_duration_for_job
        expect(user_execution_seconds_metric).to receive(:observe).with(labels_with_job_status, thread_cputime_duration)
        expect(completion_seconds_metric).to receive(:observe).with(labels_with_job_status, monotonic_time_duration)
      end

      it 'yields block' do
        expect { |b| middleware.call(worker, job, :test, &b) }.to yield_control.once
      end

      it 'sets queue specific metrics' do
        middleware.call(worker, job, :test) { nil }
      end

      context 'when job_duration is not available' do
        let(:queue_duration_for_job) { nil }

        it 'does not set the queue_duration_seconds histogram' do
          expect(queue_duration_seconds).not_to receive(:observe)

          middleware.call(worker, job, :test) { nil }
        end
      end

      context 'when job is retried' do
        let(:job) { { 'retry_count' => 1 } }

        it 'sets sidekiq_jobs_retried_total metric' do
          expect(retried_total_metric).to receive(:increment)

          middleware.call(worker, job, :test) { nil }
        end
      end

      context 'when error is raised' do
        let(:job_status) { :fail }

        it 'sets sidekiq_jobs_failed_total and reraises' do
          expect(failed_total_metric).to receive(:increment).with(labels, 1)

          expect { middleware.call(worker, job, :test) { raise StandardError, "Failed" } }.to raise_error(StandardError, "Failed")
        end
      end
    end
  end
end
