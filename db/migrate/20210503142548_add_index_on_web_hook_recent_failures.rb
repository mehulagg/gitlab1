# frozen_string_literal: true

class AddIndexOnWebHookRecentFailures < ActiveRecord::Migration[6.0]
  include Gitlab::Database::MigrationHelpers

  INDEX_NAME = 'index_web_hooks_on_recent_failures'

  disable_ddl_transaction!

  def up
    add_concurrent_index(:web_hooks, :recent_failures, name: INDEX_NAME)
  end

  def down
    remove_concurrent_index_by_name(:web_hooks, INDEX_NAME)
  end
end
