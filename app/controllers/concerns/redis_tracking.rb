# frozen_string_literal: true

# Example:
#
# # In controller include module
# # Track event for index action
#
# include RedisTracking
#
# track_redis_hll_event :index, :show, name: 'i_analytics_dev_ops_score'
module RedisTracking
  extend ActiveSupport::Concern

  class_methods do
    def track_redis_hll_event(*controller_actions, name:)
      after_action only: controller_actions, if: -> { request.format.html? && request.headers['DNT'] != '1' } do
        track_unique_redis_hll_event(name)
      end
    end
  end

  private

  def track_unique_redis_hll_event(event_name)
    return unless Gitlab::CurrentSettings.usage_ping_enabled?
    return unless visitor_id

    Gitlab::UsageDataCounters::HLLRedisCounter.track_event(visitor_id, event_name)
  end

  def visitor_id
    return cookies[:visitor_id] if cookies[:visitor_id].present?
    return unless current_user

    uuid = SecureRandom.uuid
    cookies[:visitor_id] = { value: uuid, expires: 24.months }
    uuid
  end
end
