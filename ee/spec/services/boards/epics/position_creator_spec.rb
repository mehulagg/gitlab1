# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Boards::Epics::PositionCreator do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:board) { create(:epic_board, group: group) }
  let_it_be(:label) { create(:group_label, group: group, name: 'Development') }

  let_it_be(:list)  { create(:epic_list, epic_board: board, list_type: :backlog) }
  let_it_be(:labeled_list) { create(:epic_list, epic_board: board, label: label) }

  let_it_be(:epic1) { create(:epic, group: group) }
  let_it_be(:epic2) { create(:epic, group: group) }
  let_it_be(:epic3) { create(:epic, group: group) }
  let_it_be(:epic4) { create(:epic, group: group) }
  let_it_be(:epic_other_group) { create(:epic, group: create(:group)) }
  let_it_be(:labeled_epic) { create(:labeled_epic, group: group, labels: [label]) }

  let(:params) { { board_id: board.id, list_id: list.id } }

  describe '#execute' do
    before do
      stub_licensed_features(epics: true)
      group.add_developer(user)
    end

    context 'with invalid params' do
      it 'raises an error when board_id is missing' do
        expect { described_class.new(group, user, { list_id: list.id }).execute }
          .to raise_error(ArgumentError, 'board_id param is missing')
      end

      it 'raises an error when list_id is missing' do
        expect { described_class.new(group, user, { board_id: board.id }).execute }
          .to raise_error(ArgumentError, 'list_id param is missing')
      end
    end

    context 'with correct params' do
      subject { described_class.new(group, user, params).execute }

      context 'without additional params' do
        context 'when there are no positions' do
          it 'creates the positions for all epics in the list' do
            expect { subject }.to change { Boards::EpicBoardPosition.count }.by(4)
          end

          it 'sets the relative_position based on id' do
            subject

            expect(Boards::EpicBoardPosition.order(:relative_position).map(&:epic_id))
              .to eq([epic4.id, epic3.id, epic2.id, epic1.id])
          end
        end

        context 'when some positions exist' do
          let_it_be(:epic_position1) { create(:epic_board_position, epic: epic1, epic_board: board, relative_position: 1000) }
          let_it_be(:epic_position3) { create(:epic_board_position, epic: epic3, epic_board: board, relative_position: 10) }

          it 'creates the positions for non existing epics in the list' do
            expect { subject }.to change { Boards::EpicBoardPosition.count }.by(2)
          end

          it 'sets the relative_position based on id after the last existing position' do
            subject

            expect(Boards::EpicBoardPosition.order(:relative_position).map(&:epic_id))
              .to eq([epic3.id, epic1.id, epic4.id, epic2.id])
          end

          it 'does not update the existing epic positions' do
            subject

            expect(epic_position1.reload.relative_position).to eq(1000)
            expect(epic_position3.reload.relative_position).to eq(10)
          end
        end
      end

      context 'with additional params' do
        let(:params) { { board_id: board.id, list_id: list.id, from_id: epic2.id } }

        it 'creates the positions for all epics until the last param' do
          expect { subject }.to change { Boards::EpicBoardPosition.count }.by(3)
        end

        it 'sets the relative_position based on id' do
          subject

          expect(Boards::EpicBoardPosition.order(:relative_position).map(&:epic_id))
            .to eq([epic4.id, epic3.id, epic2.id])
        end
      end
    end
  end
end
