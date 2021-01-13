# frozen_string_literal: true

module EE
  module Backup
    class Repositories
      extend ::Gitlab::Utils::Override

      override :restore
      def restore
        restore_group_repositories

        super
      end

      private

      override :repository_storages_klasses
      def repository_storages_klasses
        super << GroupWikiRepository
      end

      def restore_group_repositories
        Group.find_each(batch_size: 1000) do |group|
          restore_repository(group, Gitlab::GlRepository::WIKI)
        end
      end

      override :dump_container
      def dump_container(container)
        case container
        when Group
          dump_group(container)
        else
          super
        end
      end

      override :dump_consecutive
      def dump_consecutive
        dump_consecutive_groups

        super
      end

      def dump_consecutive_groups
        Group.find_each(batch_size: 1000) { |group| dump_group(group) }
      end

      def dump_group(group)
        backup_repository(group, Gitlab::GlRepository::WIKI)
      end

      override :records_to_enqueue
      def records_to_enqueue(storage)
        super << groups_in_storagge(storage)
      end

      def groups_in_storage(storage)
        Group.id_in(GroupWikiRepository.for_repository_storage(storage).select(:group_id))
      end
    end
  end
end
