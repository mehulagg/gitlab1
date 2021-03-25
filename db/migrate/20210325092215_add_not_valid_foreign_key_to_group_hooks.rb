# frozen_string_literal: true

class AddNotValidForeignKeyToGroupHooks < ActiveRecord::Migration[6.0]
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  def up
    add_foreign_key :web_hooks, :namespaces, column: :group_id, on_delete: :cascade, validate: false
  end

  def down
    remove_foreign_key_if_exists :web_hooks, column: :group_id
  end
end
