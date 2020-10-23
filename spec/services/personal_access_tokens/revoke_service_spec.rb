# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PersonalAccessTokens::RevokeService do
  shared_examples_for 'a successfully revoked token' do
    it { expect(subject.success?).to be true }
    it { expect(service.token.revoked?).to be true }
  end

  shared_examples_for 'an unsuccessfully revoked token' do
    it { expect(subject.success?).to be false }
    it { expect(service.token.revoked?).to be false }
    it 'logs the event' do
      expect(Gitlab::AppLogger).to receive(:info).with(/User #{current_user.username} has revoked personal access token with id \d+ for user #{token.user.username}/)
      subject
    end
  end

  describe '#execute' do
    subject { service.execute }

    let(:service) { described_class.new(current_user, token: token) }

    context 'when current_user is an administrator' do
      let_it_be(:current_user) { create(:admin) }
      let_it_be(:token) { create(:personal_access_token) }

      it_behaves_like 'a successfully revoked token'
    end

    context 'when current_user is not an administrator' do
      let_it_be(:current_user) { create(:user) }

      context 'token belongs to a different user' do
        let_it_be(:token) { create(:personal_access_token) }

        it_behaves_like 'an unsuccessfully revoked token'
      end

      context 'token belongs to current_user' do
        let_it_be(:token) { create(:personal_access_token, user: current_user) }

        it_behaves_like 'a successfully revoked token'
      end
    end
  end
end
