module Gitlab
  module Verify
    class LfsObjects < BatchVerifier
      prepend ::EE::Gitlab::Verify::LfsObjects

      def name
        'LFS objects'
      end

      def describe(object)
        "LFS object: #{object.oid}"
      end

      private

      def relation
        LfsObject.all
      end

      def expected_checksum(lfs_object)
        lfs_object.oid
      end

      def actual_checksum(lfs_object)
        LfsObject.calculate_oid(lfs_object.file.path)
      end
    end
  end
end
