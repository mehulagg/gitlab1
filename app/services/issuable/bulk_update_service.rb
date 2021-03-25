# frozen_string_literal: true

module Issuable
  class BulkUpdateService
    include Gitlab::Allowable

    attr_accessor :parent, :current_user, :params

    def initialize(parent, user = nil, params = {})
      @parent = parent
      @current_user = user
      @params = params.dup
    end

    def execute(type)
      ids = params.delete(:issuable_ids).split(",")
      set_update_params(type)
      updated_issuables = update_issuables(type, ids)

      if !updated_issuables.empty? && requires_count_cache_refresh?(type)
        schedule_group_count_refresh(type, updated_issuables)
      end

      response_success(payload: { count: updated_issuables.size })
    rescue ArgumentError => e
      response_error(e.message, 422)
    end

    private

    def set_update_params(type)
      params.slice!(*permitted_attrs(type))
      params.delete_if { |k, v| v.blank? }

      if params[:assignee_ids] == [IssuableFinder::Params::NONE.to_s]
        params[:assignee_ids] = []
      end
    end

    def permitted_attrs(type)
      attrs = %i(state_event milestone_id add_label_ids remove_label_ids subscription_event)

      attrs.push(:sprint_id) if type == 'issue'

      if type == 'issue' || type == 'merge_request'
        attrs.push(:assignee_ids)
      else
        attrs.push(:assignee_id)
      end
    end

    def update_issuables(type, ids)
      model_class = type.classify.constantize
      update_class = type.classify.pluralize.constantize::UpdateService
      items = find_issuables(parent, model_class, ids)

      items.each do |issuable|
        next unless can?(current_user, :"update_#{type}", issuable)

        update_class.new(issuable.issuing_parent, current_user, params).execute(issuable)
      end

      items
    end

    def find_issuables(parent, model_class, ids)
      if parent.is_a?(Project)
        projects = parent
      elsif parent.is_a?(Group)
        projects = parent.all_projects
      else
        return
      end

      model_class
        .id_in(ids)
        .of_projects(projects)
        .includes_for_bulk_update
    end

    def response_success(message: nil, payload: nil)
      ServiceResponse.success(message: message, payload: payload)
    end

    def response_error(message, http_status)
      ServiceResponse.error(message: message, http_status: http_status)
    end

    def requires_count_cache_refresh?(type)
      type.to_sym == :issue && params.include?(:state_event)
    end

    def schedule_group_count_refresh(issuable_type, updated_issuables)
      group_ids = updated_issuables.map(&:project).map { |project| project.group&.id }.uniq
      return unless group_ids.any?

      Issuables::RefreshGroupsCounterWorker.perform_async(issuable_type, current_user.id, group_ids)
    end
  end
end

Issuable::BulkUpdateService.prepend_if_ee('EE::Issuable::BulkUpdateService')
