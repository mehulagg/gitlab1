# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::UsageDataMetrics do
  describe '.uncached_data' do
    subject { described_class.uncached_data }

    before do
      allow(ActiveRecord::Base.connection).to receive(:transaction_open?).and_return(false)
    end

    context 'whith instrumentation_class' do
      it 'includes top level keys' do
        expect(subject).to include(:uuid)
      end

      it 'includes counts keys' do
        expect(subject[:counts]).to include(:boards)
        expect(subject[:counts]).to include(:issues)
      end

      it 'includes usage_activity_by_stage keys' do
        expect(subject[:usage_activity_by_stage][:plan]).to include(:issues)
      end

      it 'includes usage_activity_by_stage_monthly keys' do
        expect(subject[:usage_activity_by_stage_monthly][:plan]).to include(:issues)
      end
    end
  end
end
