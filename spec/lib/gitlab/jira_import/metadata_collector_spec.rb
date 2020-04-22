# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::JiraImport::MetadataCollector do
  describe '#execute' do
    let(:key) { 'PROJECT-5' }
    let(:summary) { 'some title' }
    let(:description) { 'basic description' }
    let(:created_at) { '2020-01-01 20:00:00' }
    let(:updated_at) { '2020-01-10 20:00:00' }
    let(:assignee) { double(displayName: 'Solver') }
    let(:jira_status) { 'new' }

    let(:parent_field) do
      { 'key' => 'FOO-2', 'id' => '1050', 'fields' => { 'summary' => 'parent issue FOO' } }
    end
    let(:issue_type_field) { { 'name' => 'Task' } }
    let(:fix_versions_field) { [{ 'name' => '1.0' }, { 'name' => '1.1' }] }
    let(:priority_field) { { 'name' => 'Medium' } }
    let(:labels_field) { %w(bug backend) }
    let(:environment_field) { 'staging' }
    let(:duedate_field) { '2020-03-01' }

    let(:fields) do
      {
        'parent' => parent_field,
        'issuetype' => issue_type_field,
        'fixVersions' => fix_versions_field,
        'priority' => priority_field,
        'labels' => labels_field,
        'environment' => environment_field,
        'duedate' => duedate_field
      }
    end
    let(:jira_issue) do
      double(
        id: '1234',
        key: key,
        summary: summary,
        description: description,
        created: created_at,
        updated: updated_at,
        assignee: assignee,
        reporter: double(displayName: 'Reporter'),
        status: double(statusCategory: { 'key' => jira_status }),
        fields: fields
      )
    end

    subject { described_class.new(jira_issue).execute }

    context 'when all metadata fields are present' do
      it 'skips writes all fields' do
        expected_result = <<~MD
          ---

          **Issue metadata**

          - Issue type: Task
          - Priority: Medium
          - Labels: bug, backend
          - Environment: staging
          - Due date: 2020-03-01
          - Parent issue: [FOO-2] parent issue FOO
          - Fix versions: 1.0, 1.1
        MD

        expect(subject.strip).to eq(expected_result.strip)
      end
    end

    context 'when some metadata fields are missing' do
      let(:assignee) { nil }
      let(:parent_field) { nil }
      let(:fix_versions_field) { [] }
      let(:labels_field) { [] }
      let(:environment_field) { nil }

      it 'skips the missing fields' do
        expected_result = <<~MD
          ---

          **Issue metadata**

          - Issue type: Task
          - Priority: Medium
          - Due date: 2020-03-01
        MD

        expect(subject.strip).to eq(expected_result.strip)
      end
    end

    context 'when all metadata fields are missing' do
      let(:assignee) { nil }
      let(:parent_field) { nil }
      let(:issue_type_field) { nil }
      let(:fix_versions_field) { [] }
      let(:priority_field) { nil }
      let(:labels_field) { [] }
      let(:environment_field) { nil }
      let(:duedate_field) { nil }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end
end
