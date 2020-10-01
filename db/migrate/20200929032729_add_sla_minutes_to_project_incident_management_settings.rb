# frozen_string_literal: true

class AddSlaMinutesToProjectIncidentManagementSettings < ActiveRecord::Migration[6.0]
  DOWNTIME = false

  def up
    add_column :project_incident_management_settings, :sla_timer, :boolean, default: false
    add_column :project_incident_management_settings, :sla_timer_minutes, :integer
  end

  def down
    remove_column :project_incident_management_settings, :sla_timer
    remove_column :project_incident_management_settings, :sla_timer_minutes
  end
end
