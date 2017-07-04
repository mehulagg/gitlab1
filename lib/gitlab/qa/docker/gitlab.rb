require 'securerandom'
require 'net/http'
require 'uri'
require 'forwardable'

module Gitlab
  module QA
    module Docker
      class Gitlab
        extend Forwardable
        include Scenario::Actable

        # rubocop:disable Style/Semicolon

        attr_reader :release
        attr_accessor :volumes, :network

        def_delegators :release, :tag, :image, :edition

        def initialize
          @docker = Docker::Engine.new
          self.release = 'CE'
        end

        def release=(release)
          @release = Release.new(release)
        end

        def name
          @name ||= "gitlab-qa-#{edition}-#{SecureRandom.hex(4)}"
        end

        def address
          "http://#{hostname}"
        end

        def hostname
          "#{name}.#{network}"
        end

        def instance
          raise 'Please provide a block!' unless block_given?

          prepare; start; reconfigure; wait

          yield self

          teardown
        end

        def prepare
          @docker.pull(image, tag)

          return if @docker.network_exists?(network)
          @docker.network_create(network)
        end

        def start
          ensure_configured!

          @docker.run(image, tag) do |command|
            command << "-d --name #{name} -p 80:80"
            command << "--net #{network} --hostname #{hostname}"

            @volumes.to_h.each do |to, from|
              command << "--volume #{to}:#{from}:Z"
            end
          end
        end

        def reconfigure
          @docker.attach(name) do |line, wait|
            # TODO, workaround which allows to detach from the container
            #
            Process.kill('INT', wait.pid) if line =~ /gitlab Reconfigured!/
          end
        end

        def restart
          @docker.restart(name)
        end

        def teardown
          raise 'Invalid instance name!' unless name

          @docker.stop(name)
          @docker.remove(name)
        end

        def wait
          puts "GitLab URL: #{address}"
          print 'Waiting for GitLab to become available '

          if Availability.new("http://#{@docker.hostname}").check(180)
            sleep 12 # TODO, handle that better
            puts ' -> GitLab is available.'
          else
            abort ' -> GitLab unavailable!'
          end
        end

        private

        # rubocop:disable Style/GuardClause
        def ensure_configured!
          unless [name, release, network].all?
            raise 'Please configure an instance first!'
          end
        end

        class Availability
          def initialize(address)
            @uri = URI.join(address, '/help')
          end

          def check(retries)
            retries.times do
              return true if service_available?

              print '.'
              sleep 1
            end

            false
          end

          private

          def service_available?
            response = Net::HTTP.start(@uri.host, @uri.port) do |http|
              http.head2(@uri.request_uri)
            end

            response.code.to_i == 200
          rescue Errno::ECONNREFUSED, Errno::ECONNRESET, EOFError
            false
          end
        end
      end
    end
  end
end
