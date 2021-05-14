# frozen_string_literal: true

class CleanupOrphanedLfsObjectsProjects < ActiveRecord::Migration[6.0]
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  MIGRATION = 'CleanupOrphanedLfsObjectsProjects'
  DELAY_INTERVAL = 2.minutes
  BATCH_SIZE = 10_000

  disable_ddl_transaction!

  def up
    say "Scheduling `#{MIGRATION}` jobs"

    queue_background_migration_jobs_by_range_at_intervals(LfsObjectsProject, MIGRATION, DELAY_INTERVAL, batch_size: BATCH_SIZE)
  end

  def down
    # NOOP
  end
end
