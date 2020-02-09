# frozen_string_literal: true

module Gitlab
  module Ci
    module Parsers
      module Security
        class DependencyList
          def initialize(project, sha, permissions = [:all])
            @formatter = Formatters::DependencyList.new(project, sha)
            @permissions = permissions
          end

          def parse!(json_data, report)
            report_data = JSON.parse(json_data)
            report_data.fetch('dependency_files', []).each do |file|
              file['dependencies'].each do |dependency|
                report.add_dependency(formatter.format(dependency,
                                                       file['package_manager'],
                                                       file['path'],
                                                       vulnerabilities(report_data)))
              end
            end
          end

          def parse_licenses!(json_data, report)
            license_report = ::Gitlab::Ci::Reports::LicenseScanning::Report.parse_from(json_data)
            license_report.licenses.each do |license|
              report.apply_license(license)
            end
          end

          private

          def vulnerabilities(report_data)
            if permissions.include?(:all) || permissions.include?(:vulnerabilities)
              report_data['vulnerabilities']
            else
              []
            end
          end

          attr_reader :formatter, :permissions
        end
      end
    end
  end
end
