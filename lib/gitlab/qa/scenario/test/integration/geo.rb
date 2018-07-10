module Gitlab
  module QA
    module Scenario
      module Test
        module Integration
          class Geo < Scenario::Template
            ##
            # rubocop:disable Lint/MissingCopEnableDirective
            # rubocop:disable Metrics/MethodLength
            # rubocop:disable Metrics/AbcSize
            #
            def perform(release)
              release = Release.new(release)

              raise ArgumentError, 'Geo is EE only!' unless release.ee?

              Runtime::Env.require_license!

              Component::Gitlab.perform do |primary|
                primary.release = release
                primary.name = 'gitlab-primary'
                primary.network = 'geo'
                primary.omnibus_config = <<~OMNIBUS
                  geo_primary_role['enable'] = true;
                  postgresql['listen_address'] = '0.0.0.0';
                  postgresql['trust_auth_cidr_addresses'] = ['0.0.0.0/0','0.0.0.0/0'];
                  postgresql['md5_auth_cidr_addresses'] = ['0.0.0.0/0'];
                  postgresql['max_replication_slots'] = 1;
                  gitlab_rails['db_key_base'] = '4dd58204865eb41bca93bd38131d51cc';
                  gitlab_rails['monitoring_whitelist'] = ['0.0.0.0/0'];
                  sidekiq['concurrency'] = 2;
                  unicorn['worker_processes'] = 2;
                OMNIBUS

                primary.instance do
                  Component::Gitlab.perform do |secondary|
                    secondary.release = release
                    secondary.name = 'gitlab-secondary'
                    secondary.network = 'geo'
                    secondary.omnibus_config = <<~OMNIBUS
                      geo_secondary_role['enable'] = true;
                      gitlab_rails['db_key_base'] = '4dd58204865eb41bca93bd38131d51cc';
                      sidekiq['concurrency'] = 2;
                      unicorn['worker_processes'] = 2;
                      gitlab_rails['monitoring_whitelist'] = ['0.0.0.0/0'];
                    OMNIBUS

                    secondary.act do
                      # TODO, we do not wait for secondary to start because of
                      # https://gitlab.com/gitlab-org/gitlab-ee/issues/3999
                      #
                      # rubocop:disable Style/Semicolon
                      prepare; start; reconfigure

                      # shellout to instance specs
                      puts 'Running Geo primary / secondary specs!'

                      Component::Specs.perform do |specs|
                        specs.suite = 'QA::EE::Scenario::Test::Geo'
                        specs.release = release
                        specs.network = 'geo'
                        specs.args = [
                          '--primary-address', primary.address,
                          '--primary-name', primary.name,
                          '--secondary-address', secondary.address,
                          '--secondary-name', secondary.name
                        ]
                      end

                      teardown
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
