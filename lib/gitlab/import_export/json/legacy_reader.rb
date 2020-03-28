# frozen_string_literal: true

module Gitlab
  module ImportExport
    module JSON
      class LegacyReader
        class File < LegacyReader
          include Gitlab::Utils::StrongMemoize

          def initialize(path, relation_names:, allowed_path: nil)
            @path = path
            super(
              relation_names: relation_names,
              allowed_path: allowed_path)
          end

          def exist?
            ::File.exist?(@path)
          end

          protected

          def tree_hash
            strong_memoize(:tree_hash) do
              read_hash
            end
          end

          def read_hash
            ActiveSupport::JSON.decode(IO.read(@path))
          rescue => e
            Gitlab::ErrorTracking.log_exception(e)
            raise Gitlab::ImportExport::Error.new('Incorrect JSON format')
          end
        end

        class Hash < LegacyReader
          def initialize(tree_hash, relation_names:, allowed_path: nil)
            @tree_hash = tree_hash
            super(
              relation_names: relation_names,
              allowed_path: allowed_path)
          end

          def exist?
            @tree_hash.present?
          end

          protected

          attr_reader :tree_hash
        end

        def initialize(relation_names:, allowed_path:)
          @relation_names = relation_names.map(&:to_s)

          # This is legacy reader, to be used in transition
          # period before `.ndjson`,
          # we strong validate what is being readed
          @allowed_path = allowed_path
        end

        def exist?
          raise NotImplementedError
        end

        def legacy?
          true
        end

        def consume_attributes(importable_path)
          unless importable_path == @allowed_path
            raise ArgumentError, "Invalid #{importable_path} passed to `consume_attributes`. Use #{@allowed_path} instead."
          end

          attributes
        end

        def consume_relation(importable_path, key)
          unless importable_path == @allowed_path
            raise ArgumentError, "Invalid #{importable_name} passed to `consume_relation`. Use #{@allowed_path} instead."
          end

          value = relations.delete(key)

          return value unless block_given?
          return if value.nil?

          if value.is_a?(Array)
            value.each.with_index do |item, idx|
              yield(item, idx)
            end
          else
            yield(value, 0)
          end
        end

        def sort_ci_pipelines_by_id
          relations['ci_pipelines']&.sort_by! { |hash| hash['id'] }
        end

        private

        attr_reader :relation_names, :allowed_path

        def tree_hash
          raise NotImplementedError
        end

        def attributes
          @attributes ||= tree_hash.slice!(*relation_names)
        end

        def relations
          @relations ||= tree_hash.extract!(*relation_names)
        end
      end
    end
  end
end
