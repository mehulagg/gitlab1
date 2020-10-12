# frozen_string_literal: true

module Gitlab
  module Ci
    module Parsers
      module Security
        module Formatters
          class DependencyList
            def initialize(project, sha)
              @commit_path = ::Gitlab::Routing.url_helpers.project_blob_path(project, sha)
              @project = project
            end

            def format(dependency, package_manager, file_path, vulnerabilities = [])
              {
                name:     dependency['package']['name'],
                packager: packager(package_manager),
                package_manager: package_manager,
                location: formatted_location(dependency, file_path),
                version:  dependency['version'],
                vulnerabilities: formatted_vulnerabilities(vulnerabilities),
                licenses: []
              }
            end

            private

            attr_reader :commit_path, :project

            def blob_path(file_path)
              "#{commit_path}/#{file_path}"
            end

            def packager(package_manager)
              case package_manager
              when 'bundler'
                'Ruby (Bundler)'
              when 'yarn'
                'JavaScript (Yarn)'
              when 'npm'
                'JavaScript (npm)'
              when 'pip'
                'Python (pip)'
              when 'maven'
                'Java (Maven)'
              when 'composer'
                'PHP (Composer)'
              when 'conan'
                'C/C++ (Conan)'
              else
                package_manager
              end
            end

            def formatted_location(dependency, file_path)
              base_location = {
                blob_path: blob_path(file_path),
                path:      file_path
              }

              return base_location if Feature.disabled?(:path_to_vulnerable_dependency, project, default_enabled: true)

              # TODO: update this code before https://gitlab.com/gitlab-org/gitlab/-/issues/229472 is closed
              # We temporary return test dependency path to get a PoC with integration to frontend
              base_location.merge({
                                    ancestors:
                                      [{
                                         name: 'dep1',
                                         version: '1.2'
                                       },
                                       {
                                         name: 'dep2',
                                         version: '10.11'
                                       }],
                                    top_level: false
                                  })
            end

            # we know that Parsers::Security::DependencyList parses one vulnerability at a time
            # however, to keep interface compability with rest of the code and have MVC we return array
            # even tough we know that array's size will be 1
            def formatted_vulnerabilities(vulnerabilities)
              return [] if vulnerabilities.blank?

              [{ name: vulnerabilities['message'], severity: vulnerabilities['severity'].downcase }]
            end

            # Dependency List report is generated by dependency_scanning job.
            # This is how the location is generated there
            # https://gitlab.com/gitlab-org/security-products/analyzers/common/blob/a0a5074c49f34332aa3948cd9d6dc2c054cdf3a7/issue/issue.go#L169
            def location(dependency, file_path)
              {
                'file' => file_path,
                'dependency' => {
                  'package' => {
                    'name' => dependency['package']['name']
                  },
                  'version' => dependency['version']
                }
              }
            end
          end
        end
      end
    end
  end
end
