require 'spec_helper'

describe MergeRequest do
  using RSpec::Parameterized::TableSyntax

  let(:project) { create(:project, :repository) }

  subject(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  describe 'associations' do
    it { is_expected.to have_many(:approvals).dependent(:delete_all) }
    it { is_expected.to have_many(:approvers).dependent(:delete_all) }
    it { is_expected.to have_many(:approver_groups).dependent(:delete_all) }
    it { is_expected.to have_many(:approved_by_users) }
  end

  describe '#squash_in_progress?' do
    shared_examples 'checking whether a squash is in progress' do
      let(:repo_path) { subject.source_project.repository.path }
      let(:squash_path) { File.join(repo_path, "gitlab-worktree", "squash-#{subject.id}") }

      before do
        system(*%W(#{Gitlab.config.git.bin_path} -C #{repo_path} worktree add --detach #{squash_path} master))
      end

      it 'returns true when there is a current squash directory' do
        expect(subject.squash_in_progress?).to be_truthy
      end

      it 'returns false when there is no squash directory' do
        FileUtils.rm_rf(squash_path)

        expect(subject.squash_in_progress?).to be_falsey
      end

      it 'returns false when the squash directory has expired' do
        time = 20.minutes.ago.to_time
        File.utime(time, time, squash_path)

        expect(subject.squash_in_progress?).to be_falsey
      end

      it 'returns false when the source project has been removed' do
        allow(subject).to receive(:source_project).and_return(nil)

        expect(subject.squash_in_progress?).to be_falsey
      end
    end

    context 'when Gitaly squash_in_progress is enabled' do
      it_behaves_like 'checking whether a squash is in progress'
    end

    context 'when Gitaly squash_in_progress is disabled', :disable_gitaly do
      it_behaves_like 'checking whether a squash is in progress'
    end
  end

  describe '#squash?' do
    let(:merge_request) { build(:merge_request, squash: squash) }
    subject { merge_request.squash? }

    context 'unlicensed' do
      before do
        stub_licensed_features(merge_request_squash: false)
      end

      context 'disabled in database' do
        let(:squash) { false }

        it { is_expected.to be_falsy }
      end

      context 'enabled in database' do
        let(:squash) { true }

        it { is_expected.to be_falsy }
      end
    end

    context 'licensed' do
      context 'disabled in database' do
        let(:squash) { false }

        it { is_expected.to be_falsy }
      end

      context 'licensed' do
        let(:squash) { true }

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '#approvals_before_merge' do
    where(:license_value, :db_value, :expected) do
      true  | 5   | 5
      true  | nil | nil
      false | 5   | nil
      false | nil | nil
    end

    with_them do
      let(:merge_request) { build(:merge_request, approvals_before_merge: db_value) }

      subject { merge_request.approvals_before_merge }

      before do
        stub_licensed_features(merge_request_approvers: license_value)
      end

      it { is_expected.to eq(expected) }
    end
  end

  describe '#base_pipeline' do
    let!(:pipeline) { create(:ci_empty_pipeline, project: subject.project, sha: subject.diff_base_sha) }

    it { expect(subject.base_pipeline).to eq(pipeline) }
  end

  describe '#base_codeclimate_artifact' do
    before do
      allow(subject.base_pipeline).to receive(:codeclimate_artifact)
        .and_return(1)
    end

    it 'delegates to merge request diff' do
      expect(subject.base_codeclimate_artifact).to eq(1)
    end
  end

  describe '#head_codeclimate_artifact' do
    before do
      allow(subject.head_pipeline).to receive(:codeclimate_artifact)
        .and_return(1)
    end

    it 'delegates to merge request diff' do
      expect(subject.head_codeclimate_artifact).to eq(1)
    end
  end

  describe '#base_performance_artifact' do
    before do
      allow(subject.base_pipeline).to receive(:performance_artifact)
        .and_return(1)
    end

    it 'delegates to merge request diff' do
      expect(subject.base_performance_artifact).to eq(1)
    end
  end

  describe '#head_performance_artifact' do
    before do
      allow(subject.head_pipeline).to receive(:performance_artifact)
        .and_return(1)
    end

    it 'delegates to merge request diff' do
      expect(subject.head_performance_artifact).to eq(1)
    end
  end

  describe '#has_codeclimate_data?' do
    context 'with codeclimate artifact' do
      before do
        artifact = double(success?: true)
        allow(subject.head_pipeline).to receive(:codeclimate_artifact).and_return(artifact)
        allow(subject.base_pipeline).to receive(:codeclimate_artifact).and_return(artifact)
      end

      it { expect(subject.has_codeclimate_data?).to be_truthy }
    end

    context 'without codeclimate artifact' do
      it { expect(subject.has_codeclimate_data?).to be_falsey }
    end
  end

  describe '#head_sast_artifact' do
    it { is_expected.to delegate_method(:sast_artifact).to(:head_pipeline).with_prefix(:head) }
  end

  describe '#base_sast_artifact' do
    it { is_expected.to delegate_method(:sast_artifact).to(:base_pipeline).with_prefix(:base) }
  end

  describe '#has_sast_data?' do
    let(:artifact) { double(success?: true) }

    before do
      allow(merge_request).to receive(:head_sast_artifact).and_return(artifact)
    end

    it { expect(merge_request.has_sast_data?).to be_truthy }
  end

  describe '#has_base_sast_data?' do
    let(:artifact) { double(success?: true) }

    before do
      allow(merge_request).to receive(:base_sast_artifact).and_return(artifact)
    end

    it { expect(merge_request.has_base_sast_data?).to be_truthy }
  end

  describe '#sast_container_artifact' do
    it { is_expected.to delegate_method(:sast_container_artifact).to(:head_pipeline) }
  end

  describe '#has_dast_data?' do
    let(:artifact) { double(success?: true) }

    before do
      allow(merge_request).to receive(:dast_artifact).and_return(artifact)
    end

    it { expect(merge_request.has_dast_data?).to be_truthy }
  end

  describe '#dast_artifact' do
    it { is_expected.to delegate_method(:dast_artifact).to(:head_pipeline) }
  end

  %w(sast dast performance sast_container).each do |type|
    method = "expose_#{type}_data?"

    describe "##{method}" do
      before do
        allow(merge_request).to receive(:"has_#{type}_data?").and_return(true)
        allow(merge_request.project).to receive(:feature_available?).and_return(true)
      end

      it { expect(merge_request.send(method.to_sym)).to be_truthy }
    end
  end
end
