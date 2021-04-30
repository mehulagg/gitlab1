# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Issues::SetDueDate do
  let_it_be(:user) { create(:user) }
  let(:issue) { create(:issue, due_date: '2021-05-01') }

  subject(:mutation) { described_class.new(object: nil, context: { current_user: user }, field: nil) }

  specify { expect(described_class).to require_graphql_authorizations(:update_issue) }

  describe '#resolve' do
    let(:due_date) { 2.days.since }
    let(:mutated_issue) { subject[:issue] }

    subject { mutation.resolve(project_path: issue.project.full_path, iid: issue.iid, due_date: due_date) }

    it_behaves_like 'permission level for issue mutation is correctly verified'

    context 'when the user can update the issue' do
      before do
        issue.project.add_developer(user)
      end

      it 'returns the issue with updated due date', :aggregate_failures do
        expect(mutated_issue).to eq(issue)
        expect(mutated_issue.due_date).to eq(Date.today + 2.days)
        expect(subject[:errors]).to be_empty
      end

      context 'when due date is nil' do
        let(:due_date) { nil }

        it 'updates due date to be nil' do
          expect(mutated_issue.due_date).to be nil
        end
      end

      context 'when passing incorrect due date value' do
        let(:due_date) { 'test' }

        it 'updates due date to be nil' do
          expect(mutated_issue.due_date).to be nil
        end
      end
    end
  end
end
