# frozen_string_literal: true

module Gitlab
  module QueryLimiting
    class ActiveSupportSubscriber < ActiveSupport::Subscriber
      attach_to :active_record

      def sql(event)
        unless event.payload.fetch(:cached, event.payload[:name] == 'CACHE')
          Gitlab::QueryLimiting::Transaction.current&.increment
        end
      end
    end
  end
end
