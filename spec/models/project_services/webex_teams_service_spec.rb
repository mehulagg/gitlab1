# frozen_string_literal: true

require "spec_helper"

RSpec.describe WebexTeamsService do
  it_behaves_like "chat service", "Webex Teams" do
    let(:client_arguments) { webhook_url }
    let(:payload) do
      {
        markdown: be_present
      }
    end
  end
end
