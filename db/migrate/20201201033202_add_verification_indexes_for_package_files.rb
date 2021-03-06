# frozen_string_literal: true

class AddVerificationIndexesForPackageFiles < ActiveRecord::Migration[6.0]
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false
  PENDING_VERIFICATION_INDEX_NAME = "packages_packages_pending_verification"
  FAILED_VERIFICATION_INDEX_NAME = "packages_packages_failed_verification"
  NEEDS_VERIFICATION_INDEX_NAME = "packages_packages_needs_verification"

  disable_ddl_transaction!

  def up
    add_concurrent_index :packages_package_files, :verified_at, where: "(verification_state = 0)", order: { verified_at: 'ASC NULLS FIRST' }, name: PENDING_VERIFICATION_INDEX_NAME
    add_concurrent_index :packages_package_files, :verification_retry_at, where: "(verification_state = 3)", order: { verification_retry_at: 'ASC NULLS FIRST' }, name: FAILED_VERIFICATION_INDEX_NAME
    add_concurrent_index :packages_package_files, :verification_state, where: "(verification_state = 0 OR verification_state = 3)", name: NEEDS_VERIFICATION_INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name :packages_package_files, PENDING_VERIFICATION_INDEX_NAME
    remove_concurrent_index_by_name :packages_package_files, FAILED_VERIFICATION_INDEX_NAME
    remove_concurrent_index_by_name :packages_package_files, NEEDS_VERIFICATION_INDEX_NAME
  end
end
