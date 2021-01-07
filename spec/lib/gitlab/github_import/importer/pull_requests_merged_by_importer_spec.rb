# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GithubImport::Importer::PullRequestsMergedByImporter do
  let(:client) { double }
  let(:project) { create(:project, import_source: 'http://somegithub.com') }

  subject { described_class.new(project, client) }

  it { is_expected.to include_module(Gitlab::GithubImport::ParallelScheduling) }

  describe '#representation_class' do
    it { expect(subject.representation_class).to eq(Gitlab::GithubImport::Representation::PullRequest) }
  end

  describe '#importer_class' do
    it { expect(subject.importer_class).to eq(Gitlab::GithubImport::Importer::PullRequestMergedByImporter) }
  end

  describe '#collection_method' do
    it { expect(subject.collection_method).to eq(:pull_requests_merged_by) }
  end

  describe '#id_for_already_imported_cache' do
    it { expect(subject.id_for_already_imported_cache(double(number: 1))).to eq(1) }
  end

  describe '#each_object_to_import' do
    it 'fetchs the merged pull requests data' do
      pull_request = double
      create(
        :merged_merge_request,
        iid: 999,
        source_project: project,
        target_project: project
      )

      allow(client)
        .to receive(:pull_request)
        .with('http://somegithub.com', 999)
        .and_return(pull_request)

      expect { |b| subject.each_object_to_import(&b) }.to yield_with_args(pull_request)
    end
  end
end
