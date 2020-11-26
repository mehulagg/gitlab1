# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RssHelper do
  describe '#rss_url_options' do
    context 'when signed in' do
      it "includes the current_user's feed_token" do
        current_user = create(:user)
        allow(helper).to receive(:current_user).and_return(current_user)
        expect(helper.rss_url_options).to include feed_token: current_user.feed_token
      end
    end

    context 'when signed out' do
      it "does not have a feed_token" do
        allow(helper).to receive(:current_user).and_return(nil)
        expect(helper.rss_url_options[:feed_token]).to be_nil
      end
    end

    context 'when feed_token disabled' do
      it "does not have a feed_token" do
        allow(Gitlab::CurrentSettings).to receive(:feed_token_off).and_return(true)
        expect(helper.rss_url_options[:feed_token]).to be_nil
      end
    end
  end
end
