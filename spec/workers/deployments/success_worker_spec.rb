# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Deployments::SuccessWorker do
  subject { described_class.new.perform(deployment&.id) }

  context 'when successful deployment' do
    let(:deployment) { create(:deployment, :success) }

    it 'executes Deployments::AfterCreateService' do
      expect(Deployments::AfterCreateService)
        .to receive(:new).with(deployment).and_call_original

      subject
    end
  end

  context 'when canceled deployment' do
    let(:deployment) { create(:deployment, :canceled) }

    it 'does not execute Deployments::AfterCreateService' do
      expect(Deployments::AfterCreateService).not_to receive(:new)

      subject
    end
  end

  context 'when deploy record does not exist' do
    let(:deployment) { nil }

    it 'does not execute Deployments::AfterCreateService' do
      expect(Deployments::AfterCreateService).not_to receive(:new)

      subject
    end
  end
end
