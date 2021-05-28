# frozen_string_literal: true

module Ci
  module BuildTraceChunks
    class Redis < RedisBase
      private

      def with_redis(&block)
        Gitlab::Redis::SharedState.with { |redis| block.call(redis) }
      end
    end
  end
end
