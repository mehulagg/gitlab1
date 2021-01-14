# frozen_string_literal: true

require 'time'
require 'net/http'

module GDK
  module Command
    class Measure
      def initialize(urls)
        @urls = urls
      end

      def run
        abort('Please add URL(s) as an argument (e.g. http://localhost:3000/explore, /explore or https://gitlab.com/explore)') if urls.empty?
        abort('ERROR: Docker is not installed or running!') unless docker_running?

        # Check if GDK is running if local URL
        abort("ERROR: GDK is not running locally on #{GDK.config.__uri}!") if has_local_url? && !gdk_running?

        GDK::Output.notice "Starting Sitespeed measurements for #{local_urls.join(', ')}"
        run_sitespeed

        # Open directly browser with new report
        GDK::Output.notice "Opening Report open ./sitespeed_result/#{report_folder_name}/index.html"
        Shellout.new("open ./sitespeed-result/#{report_folder_name}/index.html").run
      end

      private

      attr_reader :urls

      def gdk_running?
        %w[200 302].include?(Net::HTTP.get_response(GDK.config.__uri).code)
      rescue StandardError
        false
      end

      def docker_running?
        docker_check = Shellout.new('docker info')
        docker_check.run
        docker_check.success?
      end

      def local_urls
        @local_urls ||= begin
          urls.map do |url|
            # Transform local relative URL's
            url = "#{GDK.config.__uri}#{url}" if url_is_local?(url)

            url = url.gsub('localhost', 'host.docker.internal')
            url.gsub('127.0.0.1', 'host.docker.internal')
          end
        end
      end

      def url_is_local?(url)
        url.start_with?('/')
      end

      def has_local_url?
        @has_local_url ||= urls.any? { |url| url_is_local?(url) }
      end

      def report_folder_name
        @report_folder_name ||= begin
          folder_name = @has_local_url ? Shellout.new('git rev-parse --abbrev-ref HEAD', chdir: GDK.config.gitlab.dir).run : 'external'
          folder_name + "_#{Time.new.strftime('%F-%H-%M-%S')}"
        end
      end

      def run_sitespeed
        # Start Sitespeed through docker
        docker_command = 'docker run --cap-add=NET_ADMIN --shm-size 2g --rm -v "$(pwd):/sitespeed.io" sitespeedio/sitespeed.io:15.9.0 -b chrome '
        # 4 repetitions
        docker_command += '-n 4 '
        # Limit Cable Connection
        docker_command += '-c cable '
        # Deactivate the performance bar as it slows the measurements down
        docker_command += '--cookie perf_bar_enabled=false '
        docker_command += "--outputFolder sitespeed-result/#{report_folder_name} "
        docker_command += local_urls.join(' ')

        Shellout.new(docker_command).stream
      end
    end
  end
end
