# frozen_string_literal: true

class FetchSubscriptionPlansService
  URL = "#{EE::SUBSCRIPTIONS_URL}/gitlab_plans".freeze

  def initialize(plan:, namespace_id: nil)
    @plan = plan
    @namespace_id = namespace_id
  end

  def execute
    cached { send_request }
  end

  private

  def send_request
    response = Gitlab::HTTP.get(
      URL,
      allow_local_requests: true,
      query: { plan: @plan, namespace_id: @namespace_id },
      headers: { 'Accept' => 'application/json' }
    )

    Gitlab::Json.parse(response.body).map { |plan| Hashie::Mash.new(plan) }
  rescue => e
    Gitlab::AppLogger.info "Unable to connect to GitLab Customers App #{e}"

    nil
  end

  def cached
    if plans_data = cache.read(cache_key)
      plans_data
    else
      cache.fetch(cache_key, force: true, expires_in: 1.day) { yield }
    end
  end

  def cache
    Rails.cache
  end

  def cache_key
    if @namespace_id.present?
      "subscription-plan-#{@plan}-#{@namespace_id}"
    else
      "subscription-plan-#{@plan}"
    end
  end
end
