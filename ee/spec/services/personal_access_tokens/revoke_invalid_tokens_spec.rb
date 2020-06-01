# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PersonalAccessTokens::RevokeInvalidTokens do
  subject(:service) { described_class.new(user, expiration_date) }

  describe '#execute' do
    let(:expiration_date) { 10.days.from_now }

    let_it_be(:user) { create(:user) }
    let_it_be(:pat) { create(:personal_access_token, expires_at: 5.days.from_now, user: user) }
    let_it_be(:invalid_pat1) { create(:personal_access_token, expires_at: nil, user: user) }
    let_it_be(:invalid_pat2) { create(:personal_access_token, expires_at: 20.days.from_now, user: user) }

    context 'with a valid user and expiration date' do
      context 'with user tokens that will be revoked' do
        it 'calls mailer to send an email notifying the user' do
          expect(Notify).to receive(:policy_revoked_personal_access_tokens_email).and_call_original
          service.execute
        end

        it "revokes invalid user's tokens" do
          service.execute

          expect(pat.reload).not_to be_revoked
          expect(invalid_pat1.reload).to be_revoked
          expect(invalid_pat2.reload).to be_revoked
        end

        context 'user optout for notifications' do
          before do
            allow(user).to receive(:can?).and_return(false)
          end

          it "doesn't call mailer to send a notification" do
            expect(Notify).not_to receive(:policy_revoked_personal_access_tokens_email)
            service.execute
          end
        end
      end
    end

    context 'with no user' do
      let(:user) { nil }

      it "doesn't call mailer to send an email notifying the user" do
        expect(Notify).not_to receive(:policy_revoked_personal_access_tokens_email)
        service.execute
      end

      it "doesn't revoke user's tokens" do
        expect { service.execute }.not_to change { pat.reload.revoked }
      end
    end

    context 'with no expiration date' do
      let(:expiration_date) { nil }

      it "doesn't call mailer to send an email notifying the user" do
        expect(Notify).not_to receive(:policy_revoked_personal_access_tokens_email)
        service.execute
      end

      it "doesn't revoke user's tokens" do
        expect { service.execute }.not_to change { pat.reload.revoked }
      end
    end

    context 'when the feature flag for personal access token policy is disabled' do
      before do
        stub_feature_flags(personal_access_token_expiration_policy: false)
      end

      it "doesn't call mailer to send an email notifying the user" do
        expect(Notify).not_to receive(:policy_revoked_personal_access_tokens_email)
        service.execute
      end

      it "doesn't revoke user's tokens" do
        expect { service.execute }.not_to change { pat.reload.revoked }
      end
    end
  end
end
