# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::ResolvesIssuable do
  let_it_be(:mutation_class) do
    Class.new(Mutations::BaseMutation) do
      include Mutations::ResolvesIssuable
    end
  end

  let_it_be(:group)    { create(:group) }
  let_it_be(:user)     { create(:user) }
  let_it_be(:context)  { { current_user: user } }
  let_it_be(:mutation) { mutation_class.new(object: nil, context: context, field: nil) }

  context 'with epics' do
    let_it_be(:issuable) { create(:epic, group: group) }
    let_it_be(:parent)   { issuable.group }

    before do
      stub_licensed_features(epics: true)
    end

    it_behaves_like 'resolving an issuable in GraphQL', :epic
  end
end
