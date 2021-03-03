# frozen_string_literal: true
module Packages
  module Npm
    class PackageFinder
      delegate :find_by_version, to: :execute
      delegate :last, to: :execute

      def initialize(package_name, project: nil, namespace: nil)
        @package_name = package_name
        @project = project
        @namespace = namespace
      end

      def execute
        base.npm
            .with_name(@package_name)
            .last_of_each_version
            .preload_files
      end

      private

      def base
        if @project
          packages_for_project
        elsif @namespace
          packages_for_namespace
        else
          ::Packages::Package.none
        end
      end

      def packages_for_project
        @project.packages
      end

      def packages_for_namespace
        projects = ::Project.in_namespace(@namespace.self_and_descendants.select(:id))
        ::Packages::Package.for_projects(projects.select(:id))
      end
    end
  end
end
