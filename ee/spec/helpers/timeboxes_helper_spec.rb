# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TimeboxesHelper do
  describe '#legacy_milestone?' do
    subject { legacy_milestone?(milestone) }

    describe 'without any ResourceStateEvents' do
      let(:milestone) { double('Milestone', created_at: Date.today) }

      it { is_expected.to be_nil }
    end

    describe 'with ResourceStateEvent created before milestone' do
      let(:milestone) { double('Milestone', created_at: Date.today) }

      before do
        create(:resource_state_event, created_at: Date.yesterday)
      end

      it { is_expected.to eq(false) }
    end

    describe 'with ResourceStateEvent created same day as milestone' do
      let(:milestone) { double('Milestone', created_at: Date.today) }

      before do
        create(:resource_state_event, created_at: Date.today)
      end

      it { is_expected.to eq(false) }
    end

    describe 'with ResourceStateEvent created after milestone' do
      let(:milestone) { double('Milestone', created_at: Date.yesterday) }

      before do
        create(:resource_state_event, created_at: Date.today)
      end

      it { is_expected.to eq(true) }
    end
  end
end
