# frozen_string_literal: true

module Gitlab
  module UsageDataConcerns
    module Topology
      include Gitlab::Utils::UsageData

      JOB_TO_SERVICE_NAME = {
        'gitlab-rails' => 'web',
        'gitlab-sidekiq' => 'sidekiq',
        'gitlab-workhorse' => 'workhorse',
        'redis' => 'redis',
        'postgres' => 'postgres',
        'gitaly' => 'gitaly',
        'prometheus' => 'prometheus',
        'node' => 'node-exporter'
      }.freeze

      def topology_usage_data
        topology_data, duration = measure_duration do
          alt_usage_data(fallback: {}) { topology_fetch_all_data }
        end
        { topology: topology_data.merge(duration_s: duration) }
      end

      private

      def topology_fetch_all_data
        with_prometheus_client(fallback: {}) do |client|
          {
            nodes: topology_node_data(client)
          }
        end
      end

      def topology_node_data(client)
        # node-level data
        by_instance_mem = topology_node_memory(client)
        by_instance_cpus = topology_node_cpus(client)
        # service-level data
        by_instance_by_job_by_type_memory = topology_all_service_memory(client)
        by_instance_by_job_process_count = topology_all_service_process_count(client)

        instances = Set.new(by_instance_mem.keys + by_instance_cpus.keys)
        instances.map do |instance|
          {
            node_memory_total_bytes: by_instance_mem[instance],
            node_cpus: by_instance_cpus[instance],
            node_services:
              topology_node_services(instance, by_instance_by_job_process_count, by_instance_by_job_by_type_memory)
          }.compact
        end
      end

      def topology_node_memory(client)
        aggregate_by_instance(client, 'gitlab_usage_ping:node_memory_total_bytes:avg')
      end

      def topology_node_cpus(client)
        aggregate_by_instance(client, 'gitlab_usage_ping:node_cpus:count')
      end

      def topology_all_service_memory(client)
        {
          rss: topology_service_memory_rss(client),
          uss: topology_service_memory_uss(client),
          pss: topology_service_memory_pss(client)
        }
      end

      def topology_service_memory_rss(client)
        aggregate_by_labels(client, 'gitlab_usage_ping:node_service_process_resident_memory_bytes:avg')
      end

      def topology_service_memory_uss(client)
        aggregate_by_labels(client, 'gitlab_usage_ping:node_service_process_unique_memory_bytes:avg')
      end

      def topology_service_memory_pss(client)
        aggregate_by_labels(client, 'gitlab_usage_ping:node_service_process_proportional_memory_bytes:avg')
      end

      def topology_all_service_process_count(client)
        aggregate_by_labels(client, 'gitlab_usage_ping:node_service_process:count')
      end

      def topology_node_services(instance, all_process_counts, all_process_memory)
        # returns all node service data grouped by service name as the key
        instance_service_data =
          topology_instance_service_process_count(instance, all_process_counts)
            .deep_merge(topology_instance_service_memory(instance, all_process_memory))

        # map to list of hashes where service names become values instead, and remove
        # unknown services, since they might not be ours
        instance_service_data.each_with_object([]) do |entry, list|
          service, service_metrics = entry
          gitlab_service = JOB_TO_SERVICE_NAME[service.to_s]
          next unless gitlab_service

          list << { name: gitlab_service }.merge(service_metrics)
        end
      end

      def topology_instance_service_process_count(instance, all_instance_data)
        topology_data_for_instance(instance, all_instance_data).to_h do |metric, count|
          [metric['job'], { process_count: count }]
        end
      end

      # Given a hash mapping memory set types to Prometheus response data, returns a hash
      # mapping instance/node names to services and their respective memory use in bytes
      def topology_instance_service_memory(instance, instance_data_by_type)
        result = {}
        instance_data_by_type.each do |memory_type, instance_data|
          topology_data_for_instance(instance, instance_data).each do |metric, memory_bytes|
            job = metric['job']
            key = "process_memory_#{memory_type}".to_sym

            result[job] ||= {}
            result[job][key] ||= memory_bytes
          end
        end

        result
      end

      def topology_data_for_instance(instance, all_instance_data)
        all_instance_data.filter { |metric, _value| metric['instance'] == instance }
      end

      def drop_port(instance)
        instance.gsub(/:.+$/, '')
      end

      def one_week_average(query)
        "avg_over_time (#{query}[1w])"
      end

      def aggregate_by_instance(client, query)
        client.aggregate(one_week_average(query)) { |metric| drop_port(metric['instance']) }
      end

      # Will retain a composite key that values are mapped to
      def aggregate_by_labels(client, query)
        client.aggregate(one_week_average(query)) do |metric|
          metric['instance'] = drop_port(metric['instance'])
          metric
        end
      end
    end
  end
end
