# frozen_string_literal: true

require 'spec_helper'

RSpec.describe HousekeepingService do
  it_behaves_like 'housekeeps repository' do
    let_it_be(:resource) { create(:group_wiki) }
  end
end
