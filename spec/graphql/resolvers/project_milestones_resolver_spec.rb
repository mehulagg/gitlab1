# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ProjectMilestonesResolver do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:project) { create(:project, :private) }
    let_it_be(:current_user) { create(:user) }

    before_all do
      project.add_developer(current_user)
    end

    def resolve_project_milestones(args = {}, context = { current_user: current_user })
      resolve(described_class, obj: project, args: args, ctx: context)
    end

    it 'calls MilestonesFinder to retrieve all milestones' do
      expect(MilestonesFinder).to receive(:new)
        .with(ids: nil, project_ids: project.id, state: 'all', start_date: nil, end_date: nil)
        .and_call_original

      resolve_project_milestones
    end

    context 'when including ancestor milestones' do
      let(:parent_group) { create(:group) }
      let(:group) { create(:group, parent: parent_group) }
      let(:project) { create(:project, group: group) }

      before do
        project.add_developer(current_user)
      end

      it 'calls MilestonesFinder with correct parameters' do
        expect(MilestonesFinder).to receive(:new)
          .with(ids: nil, project_ids: project.id, group_ids: contain_exactly(group, parent_group), state: 'all', start_date: nil, end_date: nil)
          .and_call_original

        resolve_project_milestones(include_ancestors: true)
      end
    end

    context 'by ids' do
      it 'calls MilestonesFinder with correct parameters' do
        milestone = create(:milestone, project: project)

        expect(MilestonesFinder).to receive(:new)
          .with(ids: [milestone.id.to_s], project_ids: project.id, state: 'all', start_date: nil, end_date: nil)
          .and_call_original

        resolve_project_milestones(ids: [milestone.to_global_id])
      end
    end

    context 'by state' do
      it 'calls MilestonesFinder with correct parameters' do
        expect(MilestonesFinder).to receive(:new)
          .with(ids: nil, project_ids: project.id, state: 'closed', start_date: nil, end_date: nil)
          .and_call_original

        resolve_project_milestones(state: 'closed')
      end
    end

    context 'by timeframe' do
      context 'when start_date and end_date are present' do
        it 'calls MilestonesFinder with correct parameters' do
          start_date = Time.now
          end_date = Time.now + 5.days

          expect(MilestonesFinder).to receive(:new)
            .with(ids: nil, project_ids: project.id, state: 'all', start_date: start_date, end_date: end_date)
            .and_call_original

          resolve_project_milestones(start_date: start_date, end_date: end_date)
        end

        context 'when start date is after end_date' do
          it 'raises error' do
            expect do
              resolve_project_milestones(start_date: Time.now, end_date: Time.now - 2.days)
            end.to raise_error(Gitlab::Graphql::Errors::ArgumentError, "startDate is after endDate")
          end
        end
      end

      context 'when only start_date is present' do
        it 'raises error' do
          expect do
            resolve_project_milestones(start_date: Time.now)
          end.to raise_error(Gitlab::Graphql::Errors::ArgumentError, /Both startDate and endDate/)
        end
      end

      context 'when only end_date is present' do
        it 'raises error' do
          expect do
            resolve_project_milestones(end_date: Time.now)
          end.to raise_error(Gitlab::Graphql::Errors::ArgumentError, /Both startDate and endDate/)
        end
      end
    end

    context 'when user cannot read milestones' do
      it 'raises error' do
        unauthorized_user = create(:user)

        expect do
          resolve_project_milestones({}, { current_user: unauthorized_user })
        end.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end
  end
end
