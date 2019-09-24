# frozen_string_literal: true
#
module Gitlab
  module Diff
    class HighlightCache
      delegate :diffable, to: :@diff_collection
      delegate :diff_options, to: :@diff_collection

      def initialize(diff_collection, backend: Rails.cache)
        @backend = backend
        @diff_collection = diff_collection
      end

      # - Reads from cache
      # - Assigns DiffFile#highlighted_diff_lines for cached files
      def decorate(diff_file)
        if content = read_file(diff_file)
          diff_file.highlighted_diff_lines = content.map do |line|
            Gitlab::Diff::Line.init_from_hash(line)
          end
        end
      end

      # It populates a Hash in order to submit a single write to the memory
      # cache. This avoids excessive IO generated by N+1's (1 writing for
      # each highlighted line or file).
      def write_if_empty
        return unless cached_content.blank?

        @diff_collection.diff_files.each do |diff_file|
          next unless cacheable?(diff_file)

          diff_file_id = diff_file.file_identifier

          cached_content[diff_file_id] = diff_file.highlighted_diff_lines.map(&:to_hash)
        end

        cache.write(key, cached_content, expires_in: 1.week)
      end

      def exists?
        cache.exist?(key)
      end

      def clear
        cache.delete(key)
      end

      def key
        [diffable, 'highlighted-diff-files', Gitlab::Diff::Line::SERIALIZE_KEYS, diff_options]
      end

      private

      def read_file(diff_file)
        cached_content[diff_file.file_identifier]
      end

      def cache
        @backend
      end

      def cached_content
        @cached_content ||= cache.read(key) || {}
      end

      def cacheable?(diff_file)
        diffable.present? && diff_file.text? && diff_file.diffable?
      end
    end
  end
end
