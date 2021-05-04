# frozen_string_literal: true

module BulkImports
  module Exports
    class GroupConfig < BaseConfig
      private

      def base_export_path
        exportable.full_path
      end

      def import_export_yaml
        ::Gitlab::ImportExport.group_config_file
      end

      def ability
        :admin_group
      end
    end
  end
end
