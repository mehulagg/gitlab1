# frozen_string_literal: true

require 'spec_helper'

describe 'Updating a Requirement' do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:requirement) { create(:requirement, project: project) }

  let(:attributes) { { title: 'title', state: 'ARCHIVED' } }
  let(:mutation) do
    params = { project_path: project.full_path, iid: requirement.iid.to_s }.merge(attributes)

    graphql_mutation(:update_requirement, params)
  end

  shared_examples 'requirement update fails' do
    it_behaves_like 'a mutation that returns top-level errors',
      errors: ['The resource that you are attempting to access does not exist '\
               'or you don\'t have permission to perform this action']

    it 'does not update requirement' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.not_to change { requirement.reload }
    end
  end

  def mutation_response
    graphql_mutation_response(:update_requirement)
  end

  context 'when the user does not have permission' do
    before do
      stub_licensed_features(requirements: true)
    end

    it_behaves_like 'requirement update fails'
  end

  context 'when the user has permission' do
    before do
      project.add_reporter(current_user)
    end

    context 'when requirements are disabled' do
      before do
        stub_licensed_features(requirements: false)
      end

      it_behaves_like 'requirement update fails'
    end

    context 'when requirements are enabled' do
      before do
        stub_licensed_features(requirements: true)
      end

      it 'updates the requirement', :aggregate_failures do
        post_graphql_mutation(mutation, current_user: current_user)

        requirement_hash = mutation_response['requirement']
        expect(requirement_hash['title']).to eq('title')
        expect(requirement_hash['state']).to eq('ARCHIVED')
      end

      context 'when there are ActiveRecord validation errors' do
        let(:attributes) { { title: '' } }

        it_behaves_like 'a mutation that returns errors in the response',
          errors: ['Title can\'t be blank']

        it 'does not update the requirement' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.not_to change { requirement.reload }
        end
      end

      context 'when there are no update params' do
        let(:attributes) { {} }

        it_behaves_like 'a mutation that returns top-level errors',
          errors: ['title or state argument is required']
      end

      context 'when requirements_management flag is disabled' do
        before do
          stub_feature_flags(requirements_management: false)
        end

        it_behaves_like 'requirement update fails'
      end
    end
  end
end
