# frozen_string_literal: true

class AddPushRulesIdToApplicationSettings < ActiveRecord::Migration[6.0]
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  def up
    with_lock_retries do
      add_column :application_settings, :push_rule_id, :bigint
    end
  end

  def down
    with_lock_retries do
      remove_column :application_settings, :push_rule_id
    end
  end
end
