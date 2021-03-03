# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Boards::EpicLists::CreateService do
  let_it_be(:parent) { create(:group) }
  let_it_be(:board) { create(:epic_board, group: parent) }
  let_it_be(:label) { create(:group_label, group: parent, name: 'in-progress') }

  it_behaves_like 'board lists create service' do
    def create_list(params)
      create(:epic_list, params.merge(epic_board: board))
    end
  end

  context 'when epic_boards feature flag is disabled' do
    before do
      stub_feature_flags(epic_boards: false)
    end

    it 'returns an error' do
      response = described_class.new(parent, nil).execute(board)

      expect(response.success?).to eq(false)
      expect(response.errors).to include("Epic boards feature is not enabled.")
    end
  end
end
