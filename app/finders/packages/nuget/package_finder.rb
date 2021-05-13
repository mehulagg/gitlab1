# frozen_string_literal: true

module Packages
  module Nuget
    class PackageFinder
      include ::Packages::FinderHelper

      MAX_PACKAGES_COUNT = 300

      def initialize(current_user, project_or_group, package_name:, package_version: nil, limit: MAX_PACKAGES_COUNT)
        @current_user = current_user
        @project_or_group = project_or_group
        @package_name = package_name
        @package_version = package_version
        @limit = limit
      end

      def execute
        packages.limit_recent(@limit)
      end

      private

      def base
        if project?
          packages_for_project(@project_or_group)
        elsif group?
          packages_visible_to_user(@current_user, within_group: @project_or_group)
        else
          ::Packages::Package.none
        end
      end

      def packages
        result = base.nuget
                     .has_version
                     .with_name_like(@package_name)
        result = result.with_version(@package_version) if @package_version.present?
        result
      end

      def project?
        @project_or_group.is_a?(::Project)
      end

      def group?
        @project_or_group.is_a?(::Group)
      end
    end
  end
end
