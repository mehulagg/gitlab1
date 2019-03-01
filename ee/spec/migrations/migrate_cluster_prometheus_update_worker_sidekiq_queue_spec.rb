# frozen_string_literal: true

require 'spec_helper'
require Rails.root.join('ee', 'db', 'post_migrate', '20190228114524_migrate_cluster_prometheus_update_worker_sidekiq_queue.rb')

describe MigrateClusterPrometheusUpdateWorkerSidekiqQueue, :sidekiq, :redis do
  include Gitlab::Database::MigrationHelpers
  include StubWorker

  context 'when there are jobs in the queue' do
    it 'correctly migrates queue when migrating up' do
      Sidekiq::Testing.disable! do
        stubbed_worker(queue: 'gcp_cluster:cluster_update_app').perform_async('Something', [1])
        stubbed_worker(queue: 'gcp_cluster:cluster_prometheus_update').perform_async('Something', [1])

        described_class.new.up

        expect(sidekiq_queue_length('gcp_cluster:cluster_update_app')).to eq 0
        expect(sidekiq_queue_length('gcp_cluster:cluster_prometheus_update')).to eq 2
      end
    end

    it 'does not affect other queues under the same namespace' do
      Sidekiq::Testing.disable! do
        stubbed_worker(queue: 'gcp_cluster:cluster_install_app').perform_async('Something', [1])
        stubbed_worker(queue: 'gcp_cluster:cluster_provision').perform_async('Something', [1])
        stubbed_worker(queue: 'gcp_cluster:cluster_wait_for_app_installation').perform_async('Something', [1])
        stubbed_worker(queue: 'gcp_cluster:wait_for_cluster_creation').perform_async('Something', [1])
        stubbed_worker(queue: 'gcp_cluster:cluster_wait_for_ingress_ip_address').perform_async('Something', [1])
        stubbed_worker(queue: 'gcp_cluster:cluster_project_configure').perform_async('Something', [1])

        described_class.new.up

        expect(sidekiq_queue_length('gcp_cluster:cluster_install_app')).to eq 1
        expect(sidekiq_queue_length('gcp_cluster:cluster_provision')).to eq 1
        expect(sidekiq_queue_length('gcp_cluster:cluster_wait_for_app_installation')).to eq 1
        expect(sidekiq_queue_length('gcp_cluster:wait_for_cluster_creation')).to eq 1
        expect(sidekiq_queue_length('gcp_cluster:cluster_wait_for_ingress_ip_address')).to eq 1
        expect(sidekiq_queue_length('gcp_cluster:cluster_project_configure')).to eq 1
      end
    end

    it 'correctly migrates queue when migrating down' do
      Sidekiq::Testing.disable! do
        stubbed_worker(queue: 'gcp_cluster:cluster_prometheus_update').perform_async('Something', [1])

        described_class.new.down

        expect(sidekiq_queue_length('gcp_cluster:cluster_update_app')).to eq 1
        expect(sidekiq_queue_length('gcp_cluster:cluster_prometheus_update')).to eq 0
      end
    end
  end

  context 'when there are no jobs in the queues' do
    it 'does not raise error when migrating up' do
      expect { described_class.new.up }.not_to raise_error
    end

    it 'does not raise error when migrating down' do
      expect { described_class.new.down }.not_to raise_error
    end
  end
end
