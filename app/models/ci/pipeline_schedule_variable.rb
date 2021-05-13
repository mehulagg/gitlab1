# frozen_string_literal: true

module Ci
  class PipelineScheduleVariable < NamespaceShard
    extend Gitlab::Ci::Model
    include Ci::HasVariable

    belongs_to :pipeline_schedule

    alias_attribute :secret_value, :value

    validates :key, uniqueness: { scope: :pipeline_schedule_id }
  end
end
