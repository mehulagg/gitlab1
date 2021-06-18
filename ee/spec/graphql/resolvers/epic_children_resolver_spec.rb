# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::EpicChildrenResolver do
  include GraphqlHelpers

  let_it_be_with_refind(:group) { create(:group, :private) }
  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:base_epic) { create(:epic, group: group) }
  let_it_be(:child1) { create(:epic, group: group, parent: base_epic) }
  let_it_be(:child2) { create(:epic, group: group, parent: base_epic) }
  let_it_be_with_reload(:confidential_epic) { create(:epic, :confidential, group: group) }
  let_it_be(:confidential_child1) { create(:epic, :confidential, group: group, parent: confidential_epic) }
  let_it_be(:confidential_child2) { create(:epic, :confidential, group: group, parent: confidential_epic) }

  let(:args) { { include_descendant_groups: true } }

  before do
    stub_licensed_features(epics: true)
  end

  describe '#resolve' do
    it 'returns nothing when feature disabled' do
      stub_licensed_features(epics: false)

      expect(resolve_children(base_epic, args)).to be_empty
    end

    it 'does not return children epics when user has no access to group epics' do
      expect(resolve_children(base_epic, args)).to be_empty
    end

    context 'when user has access to the group epics' do
      before do
        group.add_developer(current_user)
      end

      it 'returns non confidential children epics' do
        expect(resolve_children(base_epic, args)).to contain_exactly(child1, child2)
      end

      it 'returns confidential children' do
        expect(resolve_children(confidential_epic, args))
          .to contain_exactly(confidential_child1, confidential_child2)
      end

      context 'with subgroups' do
        let_it_be(:sub_group) { create(:group, :private, parent: group) }
        let_it_be(:child3)    { create(:epic, group: sub_group, parent: base_epic) }

        before do
          sub_group.add_developer(current_user)
        end

        it 'returns all children' do
          expect(resolve_children(base_epic, args)).to contain_exactly(child1, child2, child3)
        end

        it 'does not return sub-group epics when include_descendant_groups is false' do
          expect(resolve_children(base_epic, { include_descendant_groups: false }))
            .to contain_exactly(child1, child2)
        end
      end
    end

    context 'when user is a guest' do
      before do
        group.add_guest(current_user)
      end

      it 'returns non confidential children epics' do
        expect(resolve_children(base_epic, args)).to contain_exactly(child1, child2)
      end

      it 'does not return confidential epics' do
        expect(resolve_children(confidential_epic, args)).to be_empty
      end
    end
  end

  def resolve_children(object, args = {}, context = { current_user: current_user })
    resolve(described_class, obj: object, args: args, ctx: context)
  end
end
