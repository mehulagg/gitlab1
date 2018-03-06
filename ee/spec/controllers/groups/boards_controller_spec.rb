require 'spec_helper'

describe Groups::BoardsController do
  let(:group) { create(:group) }
  let(:user) { create(:user) }

  before do
    allow(Ability).to receive(:allowed?).and_call_original
    group.add_master(user)
    sign_in(user)
    stub_licensed_features(group_issue_boards: true)
  end

  describe 'GET index' do
    it 'creates a new board when group does not have one' do
      expect { list_boards }.to change(group.boards, :count).by(1)
    end

    context 'when format is HTML' do
      it 'renders template' do
        list_boards

        expect(response).to render_template :index
        expect(response.content_type).to eq 'text/html'
      end

      context 'with unauthorized user' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :read_group, group).and_return(false)
        end

        it 'returns a not found 404 response' do
          list_boards

          expect(response).to have_gitlab_http_status(404)
          expect(response.content_type).to eq 'text/html'
        end
      end
    end

    context 'when format is JSON' do
      it 'returns a list of group boards' do
        create(:board, group: group, milestone: create(:milestone, group: group))
        create(:board, group: group, milestone_id: Milestone::Upcoming.id)

        list_boards format: :json

        parsed_response = JSON.parse(response.body)

        expect(response).to match_response_schema('boards')
        expect(parsed_response.length).to eq 2
      end

      context 'with unauthorized user' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :read_group, group).and_return(false)
        end

        it 'returns a not found 404 response' do
          list_boards format: :json

          expect(response).to have_gitlab_http_status(404)
          expect(response.content_type).to eq 'application/json'
        end
      end
    end

    it_behaves_like 'disabled when using an external authorization service' do
      subject { list_boards }
    end

    def list_boards(format: :html)
      get :index, group_id: group, format: format
    end
  end

  describe 'GET show' do
    let!(:board) { create(:board, group: group) }

    context 'when format is HTML' do
      it 'renders template' do
        read_board board: board

        expect(response).to render_template :show
        expect(response.content_type).to eq 'text/html'
      end

      context 'with unauthorized user' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :read_group, group).and_return(false)
        end

        it 'returns a not found 404 response' do
          read_board board: board

          expect(response).to have_gitlab_http_status(404)
          expect(response.content_type).to eq 'text/html'
        end
      end
    end

    context 'when format is JSON' do
      it 'returns project board' do
        read_board board: board, format: :json

        expect(response).to match_response_schema('board')
      end

      context 'with unauthorized user' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :read_group, group).and_return(false)
        end

        it 'returns a not found 404 response' do
          read_board board: board, format: :json

          expect(response).to have_gitlab_http_status(404)
          expect(response.content_type).to eq 'application/json'
        end
      end
    end

    context 'when board does not belong to group' do
      it 'returns a not found 404 response' do
        another_board = create(:board)

        read_board board: another_board

        expect(response).to have_gitlab_http_status(404)
      end
    end

    it_behaves_like 'disabled when using an external authorization service' do
      subject { read_board board: board }
    end

    def read_board(board:, format: :html)
      get :show, group_id: group,
                 id: board.to_param,
                 format: format
    end
  end
end
