# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::UuidMetric do
  it_behaves_like 'a correct instrumented metric value', Gitlab::CurrentSettings.uuid
end
