# rubocop:disable RSpec/FactoriesInMigrationSpecs
require 'spec_helper'
require Rails.root.join('db', 'post_migrate', '20180723130817_delete_inconsistent_internal_id_records.rb')

describe DeleteInconsistentInternalIdRecords, :migration do
  let!(:project1) { create(:project) }
  let!(:project2) { create(:project) }
  let!(:project3) { create(:project) }

  let(:internal_id_query) { ->(project) { InternalId.where(usage: InternalId.usages[scope.to_s.tableize], project: project) } }
  let(:scope_column) { :project }
  let(:model_columns) { {} }

  def at_least_times(how_often, &block)
    [how_often, rand(how_often + 5)].max.times(&block)
  end

  let(:create_models) do
    -> do
      at_least_times(3) { create(scope, scope_column => project1) }
      at_least_times(3) { create(scope, scope_column => project2) }
      at_least_times(3) { create(scope, scope_column => project3) }
    end
  end

  shared_examples_for 'deleting inconsistent internal_id records' do
    before do
      create_models.call()

      internal_id_query.call(project1).first.tap do |iid|
        iid.last_value = iid.last_value - 2
        # This is an inconsistent record
        iid.save!
      end

      internal_id_query.call(project3).first.tap do |iid|
        iid.last_value = iid.last_value + 2
        # This is a consistent record
        iid.save!
      end
    end

    it "deletes inconsistent issues" do
      expect { migrate! }.to change { internal_id_query.call(project1).size }.from(1).to(0)
    end

    it "retains consistent issues" do
      expect { migrate! }.not_to change { internal_id_query.call(project2).size }
    end

    it "retains consistent records, especially those with a greater last_value" do
      expect { migrate! }.not_to change { internal_id_query.call(project3).size }
    end
  end

  context 'for issues' do
    let(:scope) { :issue }
    it_behaves_like 'deleting inconsistent internal_id records'
  end

  context 'for merge_requests' do
    let(:scope) { :merge_request }
    let(:scope_column) { :target_project }

    let(:create_models) do
      -> do
        at_least_times(3) { |i| create(scope, scope_column => project1, source_project: project1, source_branch: i.to_s) }
        at_least_times(3) { |i| create(scope, scope_column => project2, source_project: project2, source_branch: i.to_s) }
        at_least_times(3) { |i| create(scope, scope_column => project3, source_project: project3, source_branch: i.to_s) }
      end
    end

    it_behaves_like 'deleting inconsistent internal_id records'
  end

  context 'for deployments' do
    let(:scope) { :deployment }
    it_behaves_like 'deleting inconsistent internal_id records'
  end

  context 'for milestones (by project)' do
    let(:scope) { :milestone }
    it_behaves_like 'deleting inconsistent internal_id records'
  end

  context 'for ci_pipelines' do
    let(:scope) { :ci_pipeline }
    it_behaves_like 'deleting inconsistent internal_id records'
  end

  context 'for milestones (by group)' do
    # milestones (by group) is a little different than all of the other models
    let!(:group1) { create(:group) }
    let!(:group2) { create(:group) }
    let!(:group3) { create(:group) }

    let(:internal_id_query) { ->(group) { InternalId.where(usage: InternalId.usages['milestones'], namespace: group) } }

    before do
      at_least_times(3) { create(:milestone, group: group1) }
      at_least_times(3) { create(:milestone, group: group2) }
      at_least_times(3) { create(:milestone, group: group3) }

      internal_id_query.call(group1).first.tap do |iid|
        iid.last_value = iid.last_value - 2
        # This is an inconsistent record
        iid.save!
      end

      internal_id_query.call(group3).first.tap do |iid|
        iid.last_value = iid.last_value + 2
        # This is a consistent record
        iid.save!
      end
    end

    it "deletes inconsistent issues" do
      expect { migrate! }.to change { internal_id_query.call(group1).size }.from(1).to(0)
    end

    it "retains consistent issues" do
      expect { migrate! }.not_to change { internal_id_query.call(group2).size }
    end

    it "retains consistent records, especially those with a greater last_value" do
      expect { migrate! }.not_to change { internal_id_query.call(group3).size }
    end
  end
end
