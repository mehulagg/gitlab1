# frozen_string_literal: true

class CreateExternalStatusChecksTable < ActiveRecord::Migration[6.1]
  include Gitlab::Database::MigrationHelpers
  disable_ddl_transaction!

  def up
    create_table_with_constraints :external_status_checks, if_not_exists: true do |t|
      t.references :project, foreign_key: { on_delete: :cascade }, null: false, index: false
      t.timestamps_with_timezone
      t.text :external_url, null: false
      t.text_limit :external_url, 255
      t.text :name, null: false
      t.text_limit :name, 255

      t.index([:project_id, :name],
              unique: true,
              name: 'idx_on_external_status_checks_project_id_name')
      t.index([:project_id, :external_url],
              unique: true,
              name: 'idx_on_external_status_checks_project_id_external_url')
    end

    create_table :external_status_checks_protected_branches do |t|
      t.references :external_status_check, null: false, index: { name: 'idx_external_status_checks_protected_branches_on_esc_id' }, foreign_key: true
      t.references :protected_branch, null: false, index: { name: 'idx_esc_protected_branches_on_protected_branch_id' }, foreign_key: true
    end
  end

  def down
    with_lock_retries do
      drop_table :external_status_checks_protected_branches, force: :cascade, if_exists: true
    end

    with_lock_retries do
      drop_table :external_status_checks, force: :cascade, if_exists: true
    end
  end
end
