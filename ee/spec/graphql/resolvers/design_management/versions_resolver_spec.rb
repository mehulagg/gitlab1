# frozen_string_literal: true

require 'spec_helper'

describe Resolvers::DesignManagement::VersionsResolver do
  include GraphqlHelpers
  include DesignManagementTestHelpers

  describe "#resolve" do
    let(:resolver) { described_class }
    let_it_be(:issue) { create(:issue) }
    let_it_be(:authorized_user) { create(:user) }
    let_it_be(:first_version) { create(:design_version, issue: issue) }
    let_it_be(:other_version) { create(:design_version, issue: issue) }
    let_it_be(:first_design) { create(:design, issue: issue, versions: [first_version, other_version]) }
    let_it_be(:other_design) { create(:design, :with_versions, issue: issue) }

    let(:project) { issue.project }
    let(:params) { {} }
    let(:current_user) { authorized_user }
    let(:parent_args) { { irrelevant: 1.2 } }
    let(:parent) { double('Parent', parent: nil, irep_node: double(arguments: parent_args)) }

    before do
      enable_design_management
      project.add_developer(authorized_user)
    end

    shared_examples 'a source of versions' do
      subject(:result) { resolve_versions(object) }

      let_it_be(:all_versions) { object.versions.ordered }

      context 'when the user is not authorized' do
        let(:current_user) { create(:user) }

        it { is_expected.to be_empty }
      end

      context 'without constraints' do
        it "returns the ordered versions" do
          expect(result).to eq(all_versions)
        end
      end

      context 'when constrained' do
        let_it_be(:matching) { all_versions.earlier_or_equal_to(first_version) }

        shared_examples 'a query for all_versions up to the first_version' do
          it { is_expected.to eq(matching) }
        end

        context 'by earlier_or_equal_to_id' do
          let(:params) { { id: global_id_of(first_version) } }

          it_behaves_like 'a query for all_versions up to the first_version'
        end

        context 'by earlier_or_equal_to_sha' do
          let(:params) { { sha: first_version.sha } }

          it_behaves_like 'a query for all_versions up to the first_version'
        end

        context 'by earlier_or_equal_to_sha AND earlier_or_equal_to_id' do
          context 'and they match' do
            # This usage is rather dumb, but so long as they match, this will
            # return successfully
            let(:params) do
              {
                sha: first_version.sha,
                id:  global_id_of(first_version)
              }
            end

            it_behaves_like 'a query for all_versions up to the first_version'
          end

          context 'and they do not match' do
            let(:params) do
              {
                sha: first_version.sha,
                id:  global_id_of(other_version)
              }
            end

            it 'raises a suitable error' do
              expect { result }.to raise_error(GraphQL::ExecutionError)
            end
          end
        end

        context 'by at_version in parent' do
          let(:parent_args) { { atVersion: global_id_of(first_version) } }

          it_behaves_like 'a query for all_versions up to the first_version'
        end
      end
    end

    describe 'a design collection' do
      let_it_be(:object) { DesignManagement::DesignCollection.new(issue) }

      it_behaves_like 'a source of versions'
    end

    describe 'a design' do
      let_it_be(:object) { first_design }

      it_behaves_like 'a source of versions'
    end

    def resolve_versions(obj, context = { current_user: current_user })
      eager_resolve(resolver, obj: obj, args: params.merge(parent: parent), ctx: context)
    end
  end
end
