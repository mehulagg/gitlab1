class AddFileStoreJobArtifacts < ActiveRecord::Migration
  include Gitlab::Database::MigrationHelpers

  disable_ddl_transaction!
  DOWNTIME = false

  def up
    add_column(:ci_job_artifacts, :file_store, :integer)

    # Run on an empty table, but else Rubocop is not happy
    add_concurrent_index(:ci_job_artifacts, :file_store)
  end

  def down
    remove_column(:ci_job_artifacts, :file_store)
  end
end
