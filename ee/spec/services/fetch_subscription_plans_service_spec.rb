# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchSubscriptionPlansService do
  describe '#execute' do
    let(:endpoint_url) { "#{EE::SUBSCRIPTIONS_URL}/gitlab_plans" }

    subject { described_class.new(plan: 'bronze').execute }

    context 'when successully fetching plans data' do
      it 'returns parsed JSON' do
        json_mock = double(body: [{ 'foo' => 'bar' }].to_json)

        expect(Gitlab::HTTP).to receive(:get)
          .with(
            endpoint_url,
            allow_local_requests: true,
            query: { plan: 'bronze', namespace_id: nil },
            headers: { 'Accept' => 'application/json' }
          )
          .and_return(json_mock)

        is_expected.to eq([Hashie::Mash.new('foo' => 'bar')])
      end

      context 'with given namespace_id' do
        subject { described_class.new(plan: 'bronze', namespace_id: namespace_id).execute }

        let(:namespace_id) { 87 }

        it 'returns parsed JSON' do
          json_mock = double(body: [{ 'foo' => 'bar' }].to_json)

          expect(Gitlab::HTTP).to receive(:get)
            .with(
              endpoint_url,
              allow_local_requests: true,
              query: { plan: 'bronze', namespace_id: namespace_id },
              headers: { 'Accept' => 'application/json' }
            )
            .and_return(json_mock)

          is_expected.to eq([Hashie::Mash.new('foo' => 'bar')])
        end
      end
    end

    context 'when failing to fetch plans data' do
      before do
        expect(Gitlab::HTTP).to receive(:get).and_raise(Gitlab::HTTP::Error.new('Error message'))
      end

      it 'logs failure' do
        expect(Gitlab::AppLogger).to receive(:info).with('Unable to connect to GitLab Customers App Error message')

        subject
      end

      it 'returns nil' do
        is_expected.to be_nil
      end
    end
  end
end
