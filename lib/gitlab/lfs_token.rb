module Gitlab
  class LfsToken
    attr_accessor :actor

    def initialize(actor)
      @actor = actor
    end

    def generate
      token = Devise.friendly_token(50)

      Gitlab::Redis.with do |redis|
        redis.set(redis_key, token, ex: 600)
      end

      token
    end

    def value
      Gitlab::Redis.with do |redis|
        redis.get(redis_key)
      end
    end

    private

    def redis_key
      "gitlab:lfs_token:#{actor.class.name.underscore}_#{actor.id}" if actor
    end
  end
end
