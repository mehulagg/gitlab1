# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillTraversalIds::BackfillChildren, :migration, schema: 20210324060135 do
  let(:namespaces_table) { table(:namespaces) }

  let!(:user_namespace) { namespaces_table.create!(id: 1, name: 'user', path: 'user', type: nil) }
  let!(:root_group) { namespaces_table.create!(id: 2, name: 'group', path: 'group', type: 'Group', parent_id: nil) }
  let!(:sub_group) { namespaces_table.create!(id: 3, name: 'subgroup', path: 'subgroup', type: 'Group', parent_id: 2) }

  describe '#perform' do
    it 'backfills traversal_ids for child namespaces' do
      described_class.new.perform(1, 3)

      expect(user_namespace.reload.traversal_ids).to eq([])
      expect(root_group.reload.traversal_ids).to eq([])
      expect(sub_group.reload.traversal_ids).to eq([2, 3])
    end
  end
end
