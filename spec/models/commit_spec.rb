# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Commit do
  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be(:personal_snippet) { create(:personal_snippet, :repository) }
  let_it_be(:project_snippet) { create(:project_snippet, :repository) }
  let(:commit) { project.commit }

  describe 'modules' do
    subject { described_class }

    it { is_expected.to include_module(Mentionable) }
    it { is_expected.to include_module(Participable) }
    it { is_expected.to include_module(Referable) }
    it { is_expected.to include_module(StaticModel) }
    it { is_expected.to include_module(Presentable) }
  end

  describe '.lazy' do
    shared_examples '.lazy checks' do
      context 'when the commits are found' do
        let(:oids) do
          %w(
            498214de67004b1da3d820901307bed2a68a8ef6
            c642fe9b8b9f28f9225d7ea953fe14e74748d53b
            6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9
            048721d90c449b244b7b4c53a9186b04330174ec
            281d3a76f31c812dbf48abce82ccf6860adedd81
          )
        end

        subject { oids.map { |oid| described_class.lazy(container, oid) } }

        it 'batches requests for commits' do
          expect(container.repository).to receive(:commits_by).once.and_call_original

          subject.first.title
          subject.last.title
        end

        it 'maintains ordering' do
          subject.each_with_index do |commit, i|
            expect(commit.id).to eq(oids[i])
          end
        end

        it 'does not attempt to replace methods via BatchLoader' do
          subject.each do |commit|
            expect(commit).to receive(:method_missing).and_call_original

            commit.id
          end
        end
      end

      context 'when not found' do
        it 'returns nil as commit' do
          commit = described_class.lazy(container, 'deadbeef').__sync

          expect(commit).to be_nil
        end
      end
    end

    context 'with project' do
      let(:container) { project }

      it_behaves_like '.lazy checks'
    end

    context 'with personal snippet' do
      let(:container) { personal_snippet }

      it_behaves_like '.lazy checks'
    end

    context 'with project snippet' do
      let(:container) { project_snippet }

      it_behaves_like '.lazy checks'
    end
  end

  describe '#diff_refs' do
    it 'is equal to itself' do
      expect(commit.diff_refs).to eq(commit.diff_refs)
    end

    context 'from a factory' do
      let(:commit) { create(:commit) }

      it 'is equal to itself' do
        expect(commit.diff_refs).to eq(commit.diff_refs)
      end
    end
  end

  describe '#author', :request_store do
    it 'looks up the author in a case-insensitive way' do
      user = create(:user, email: commit.author_email.upcase)
      expect(commit.author).to eq(user)
    end

    it 'caches the author' do
      user = create(:user, email: commit.author_email)

      expect(commit.author).to eq(user)

      key = "Commit:author:#{commit.author_email.downcase}"

      expect(Gitlab::SafeRequestStore[key]).to eq(user)
      expect(commit.author).to eq(user)
    end

    context 'with a user with an unconfirmed e-mail' do
      before do
        user = create(:user)
        create(:email, user: user, email: commit.author_email)
      end

      it 'returns no user' do
        expect(commit.author).to be_nil
      end
    end

    context 'using eager loading' do
      let!(:alice) { create(:user, email: 'alice@example.com') }
      let!(:bob) { create(:user, email: 'hunter2@example.com') }
      let!(:jeff) { create(:user) }

      let(:alice_commit) do
        described_class.new(RepoHelpers.sample_commit, project).tap do |c|
          c.author_email = 'alice@example.com'
        end
      end

      let(:bob_commit) do
        # The commit for Bob uses one of his alternative Emails, instead of the
        # primary one.
        described_class.new(RepoHelpers.sample_commit, project).tap do |c|
          c.author_email = 'bob@example.com'
        end
      end

      let(:eve_commit) do
        described_class.new(RepoHelpers.sample_commit, project).tap do |c|
          c.author_email = 'eve@example.com'
        end
      end

      let(:jeff_commit) do
        # The commit for Jeff uses his private commit email
        described_class.new(RepoHelpers.sample_commit, project).tap do |c|
          c.author_email = jeff.private_commit_email
        end
      end

      let!(:commits) { [alice_commit, bob_commit, eve_commit, jeff_commit] }

      before do
        create(:email, :confirmed, user: bob, email: 'bob@example.com')
      end

      it 'executes only two SQL queries' do
        recorder = ActiveRecord::QueryRecorder.new do
          # Running this first ensures we don't run one query for every
          # commit.
          commits.each(&:lazy_author)

          # This forces the execution of the SQL queries necessary to load the
          # data.
          commits.each { |c| c.author.try(:id) }
        end

        expect(recorder.count).to eq(2)
      end

      it "preloads the authors for Commits matching a user's primary Email" do
        commits.each(&:lazy_author)

        expect(alice_commit.author).to eq(alice)
      end

      it "preloads the authors for Commits using a User's alternative Email" do
        commits.each(&:lazy_author)

        expect(bob_commit.author).to eq(bob)
      end

      it "preloads the authors for Commits using a User's private commit Email" do
        commits.each(&:lazy_author)

        expect(jeff_commit.author).to eq(jeff)
      end

      it "preloads the authors for Commits using a User's outdated private commit Email" do
        jeff.update!(username: 'new-username')

        commits.each(&:lazy_author)

        expect(jeff_commit.author).to eq(jeff)
      end

      it 'sets the author to Nil if an author could not be found for a Commit' do
        commits.each(&:lazy_author)

        expect(eve_commit.author).to be_nil
      end

      it 'does not execute SQL queries once the authors are preloaded' do
        commits.each(&:lazy_author)
        commits.each { |c| c.author.try(:id) }

        recorder = ActiveRecord::QueryRecorder.new do
          alice_commit.author
          bob_commit.author
          eve_commit.author
        end

        expect(recorder.count).to be_zero
      end
    end
  end

  describe '#committer' do
    context 'with a confirmed e-mail' do
      it 'returns the user' do
        user = create(:user, email: commit.committer_email)

        expect(commit.committer).to eq(user)
      end
    end

    context 'with an unconfirmed e-mail' do
      let(:user) { create(:user) }

      before do
        create(:email, user: user, email: commit.committer_email)
      end

      it 'returns no user' do
        expect(commit.committer).to be_nil
      end

      it 'returns the user' do
        expect(commit.committer(confirmed: false)).to eq(user)
      end
    end
  end

  describe '#to_reference' do
    context 'with project' do
      let(:project) { create(:project, :repository, path: 'sample-project') }

      it 'returns a String reference to the object' do
        expect(commit.to_reference).to eq commit.id
      end

      it 'supports a cross-project reference' do
        another_project = build(:project, :repository, name: 'another-project', namespace: project.namespace)
        expect(commit.to_reference(another_project)).to eq "sample-project@#{commit.id}"
      end
    end

    context 'with personal snippet' do
      let(:commit) { personal_snippet.commit }

      it 'returns a String reference to the object' do
        expect(commit.to_reference).to eq "$#{personal_snippet.id}@#{commit.id}"
      end

      it 'supports a cross-snippet reference' do
        another_snippet = build(:personal_snippet)
        expect(commit.to_reference(another_snippet)).to eq "$#{personal_snippet.id}@#{commit.id}"
      end
    end

    context 'with project snippet' do
      let(:commit) { project_snippet.commit }

      it 'returns a String reference to the object' do
        expect(commit.to_reference).to eq "$#{project_snippet.id}@#{commit.id}"
      end

      it 'supports a cross-snippet project reference' do
        another_snippet = build(:personal_snippet)
        expect(commit.to_reference(another_snippet)).to eq "#{project_snippet.project.path}$#{project_snippet.id}@#{commit.id}"
      end
    end
  end

  describe '.reference_valid?' do
    using RSpec::Parameterized::TableSyntax

    where(:ref, :result) do
      '1234567' | true
      '123456' | false
      '1' | false
      '0' * 40 | true
      'c1acaa58bbcbc3eafe538cb8274ba387047b69f8' | true
      'H1acaa58bbcbc3eafe538cb8274ba387047b69f8' | false
      nil | false
    end

    with_them do
      it { expect(described_class.reference_valid?(ref)).to eq(result) }
    end
  end

  describe '#reference_link_text' do
    let(:project) { create(:project, :repository, path: 'sample-project') }

    context 'with project' do
      it 'returns a String reference to the object' do
        expect(commit.reference_link_text).to eq commit.short_id
      end

      it 'supports a cross-project reference' do
        another_project = build(:project, :repository, name: 'another-project', namespace: project.namespace)
        expect(commit.reference_link_text(another_project)).to eq "sample-project@#{commit.short_id}"
      end
    end

    context 'with personal snippet' do
      let(:commit) { personal_snippet.commit }

      it 'returns a String reference to the object' do
        expect(commit.reference_link_text).to eq "$#{personal_snippet.id}@#{commit.short_id}"
      end

      it 'supports a cross-snippet reference' do
        another_snippet = build(:personal_snippet, :repository)
        expect(commit.reference_link_text(another_snippet)).to eq "$#{personal_snippet.id}@#{commit.short_id}"
      end
    end

    context 'with project snippet' do
      let(:commit) { project_snippet.commit }

      it 'returns a String reference to the object' do
        expect(commit.reference_link_text).to eq "$#{project_snippet.id}@#{commit.short_id}"
      end

      it 'supports a cross-snippet project reference' do
        another_snippet = build(:project_snippet, :repository)
        expect(commit.reference_link_text(another_snippet)).to eq "#{project_snippet.project.path}$#{project_snippet.id}@#{commit.short_id}"
      end
    end
  end

  describe '#title' do
    it "returns no_commit_message when safe_message is blank" do
      allow(commit).to receive(:safe_message).and_return('')
      expect(commit.title).to eq("No commit message")
    end

    it 'truncates a message without a newline at natural break to 80 characters' do
      message = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec sodales id felis id blandit. Vivamus egestas lacinia lacus, sed rutrum mauris.'

      allow(commit).to receive(:safe_message).and_return(message)
      expect(commit.title).to eq('Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec sodales id...')
    end

    it "truncates a message with a newline before 80 characters at the newline" do
      message = commit.safe_message.split(" ").first

      allow(commit).to receive(:safe_message).and_return(message + "\n" + message)
      expect(commit.title).to eq(message)
    end

    it "does not truncates a message with a newline after 80 but less 100 characters" do
      message = <<eos
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec sodales id felis id blandit.
Vivamus egestas lacinia lacus, sed rutrum mauris.
eos

      allow(commit).to receive(:safe_message).and_return(message)
      expect(commit.title).to eq(message.split("\n").first)
    end
  end

  describe '#full_title' do
    it "returns no_commit_message when safe_message is blank" do
      allow(commit).to receive(:safe_message).and_return('')
      expect(commit.full_title).to eq("No commit message")
    end

    it "returns entire message if there is no newline" do
      message = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec sodales id felis id blandit. Vivamus egestas lacinia lacus, sed rutrum mauris.'

      allow(commit).to receive(:safe_message).and_return(message)
      expect(commit.full_title).to eq(message)
    end

    it "returns first line of message if there is a newLine" do
      message = commit.safe_message.split(" ").first

      allow(commit).to receive(:safe_message).and_return(message + "\n" + message)
      expect(commit.full_title).to eq(message)
    end
  end

  describe 'description' do
    it 'returns no_commit_message when safe_message is blank' do
      allow(commit).to receive(:safe_message).and_return(nil)

      expect(commit.description).to eq('No commit message')
    end

    it 'returns description of commit message if title less than 100 characters' do
      message = <<eos
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec sodales id felis id blandit.
Vivamus egestas lacinia lacus, sed rutrum mauris.
eos

      allow(commit).to receive(:safe_message).and_return(message)
      expect(commit.description).to eq('Vivamus egestas lacinia lacus, sed rutrum mauris.')
    end

    it 'returns full commit message if commit title more than 100 characters' do
      message = <<eos
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec sodales id felis id blandit. Vivamus egestas lacinia lacus, sed rutrum mauris.
Vivamus egestas lacinia lacus, sed rutrum mauris.
eos

      allow(commit).to receive(:safe_message).and_return(message)
      expect(commit.description).to eq(message)
    end
  end

  describe "delegation" do
    subject { commit }

    it { is_expected.to respond_to(:message) }
    it { is_expected.to respond_to(:authored_date) }
    it { is_expected.to respond_to(:committed_date) }
    it { is_expected.to respond_to(:committer_email) }
    it { is_expected.to respond_to(:author_email) }
    it { is_expected.to respond_to(:parents) }
    it { is_expected.to respond_to(:date) }
    it { is_expected.to respond_to(:diffs) }
    it { is_expected.to respond_to(:id) }
  end

  it_behaves_like 'a mentionable' do
    subject { create(:project, :repository).commit }

    let(:author) { create(:user, email: subject.author_email) }
    let(:backref_text) { "commit #{subject.id}" }
    let(:set_mentionable_text) do
      ->(txt) { allow(subject).to receive(:safe_message).and_return(txt) }
    end

    # Include the subject in the repository stub.
    let(:extra_commits) { [subject] }
  end

  describe '#hook_attrs' do
    let(:data) { commit.hook_attrs(with_changed_files: true) }

    it { expect(data).to be_a(Hash) }
    it { expect(data[:message]).to include('adds bar folder and branch-test text file to check Repository merged_to_root_ref method') }
    it { expect(data[:timestamp]).to eq('2016-09-27T14:37:46+00:00') }
    it { expect(data[:added]).to contain_exactly("bar/branch-test.txt") }
    it { expect(data[:modified]).to eq([]) }
    it { expect(data[:removed]).to eq([]) }
  end

  describe '#cherry_pick_message' do
    let(:user) { create(:user) }

    context 'of a regular commit' do
      let(:commit) { project.commit('video') }

      it { expect(commit.cherry_pick_message(user)).to include("\n\n(cherry picked from commit 88790590ed1337ab189bccaa355f068481c90bec)") }
    end

    context 'of a merge commit' do
      let(:repository) { project.repository }

      let(:merge_request) do
        create(:merge_request,
               source_branch: 'video',
               target_branch: 'master',
               source_project: project,
               author: user)
      end

      let(:merge_commit) do
        merge_commit_id = repository.merge(user,
                                           merge_request.diff_head_sha,
                                           merge_request,
                                           'Test message')

        repository.commit(merge_commit_id)
      end

      context 'that is found' do
        before do
          # Artificially mark as completed.
          merge_request.update(merge_commit_sha: merge_commit.id)
        end

        it do
          expected_appended_text = <<~STR.rstrip

            (cherry picked from commit #{merge_commit.sha})

            467dc98f Add new 'videos' directory
            88790590 Upload new video file
          STR

          expect(merge_commit.cherry_pick_message(user)).to include(expected_appended_text)
        end
      end

      context "that is existing but not found" do
        it 'does not include details of the merged commits' do
          expect(merge_commit.cherry_pick_message(user)).to end_with("(cherry picked from commit #{merge_commit.sha})")
        end
      end
    end
  end

  describe '#reverts_commit?' do
    let(:another_commit) { double(:commit, revert_description: "This reverts commit #{commit.sha}") }
    let(:user) { commit.author }

    it { expect(commit.reverts_commit?(another_commit, user)).to be_falsy }

    context 'commit has no description' do
      before do
        allow(commit).to receive(:description?).and_return(false)
      end

      it { expect(commit.reverts_commit?(another_commit, user)).to be_falsy }
    end

    context "another_commit's description does not revert commit" do
      before do
        allow(commit).to receive(:description).and_return("Foo Bar")
      end

      it { expect(commit.reverts_commit?(another_commit, user)).to be_falsy }
    end

    context "another_commit's description reverts commit" do
      before do
        allow(commit).to receive(:description).and_return("Foo #{another_commit.revert_description} Bar")
      end

      it { expect(commit.reverts_commit?(another_commit, user)).to be_truthy }
    end

    context "another_commit's description reverts merged merge request" do
      before do
        revert_description = "This reverts merge request !foo123"
        allow(another_commit).to receive(:revert_description).and_return(revert_description)
        allow(commit).to receive(:description).and_return("Foo #{another_commit.revert_description} Bar")
      end

      it { expect(commit.reverts_commit?(another_commit, user)).to be_truthy }
    end
  end

  describe '#participants' do
    let(:user1) { build(:user) }
    let(:user2) { build(:user) }

    let!(:note1) do
      create(:note_on_commit,
             commit_id: commit.id,
             project: project,
             note: 'foo')
    end

    let!(:note2) do
      create(:note_on_commit,
             commit_id: commit.id,
             project: project,
             note: 'bar')
    end

    before do
      allow(commit).to receive(:author).and_return(user1)
      allow(commit).to receive(:committer).and_return(user2)
    end

    it 'includes the commit author' do
      expect(commit.participants).to include(commit.author)
    end

    it 'includes the committer' do
      expect(commit.participants).to include(commit.committer)
    end

    it 'includes the authors of the commit notes' do
      expect(commit.participants).to include(note1.author, note2.author)
    end
  end

  shared_examples '#uri_type' do
    it 'returns the URI type at the given path' do
      expect(commit.uri_type('files/html')).to be(:tree)
      expect(commit.uri_type('files/images/logo-black.png')).to be(:raw)
      expect(commit.uri_type('files/images/wm.svg')).to be(:raw)
      expect(project.commit('audio').uri_type('files/audio/clip.mp3')).to be(:raw)
      expect(project.commit('audio').uri_type('files/audio/sample.wav')).to be(:raw)
      expect(project.commit('video').uri_type('files/videos/intro.mp4')).to be(:raw)
      expect(commit.uri_type('files/js/application.js')).to be(:blob)
    end

    it "returns nil if the path doesn't exists" do
      expect(commit.uri_type('this/path/doesnt/exist')).to be_nil
      expect(commit.uri_type('../path/doesnt/exist')).to be_nil
    end

    it 'is nil if the path is nil or empty' do
      expect(commit.uri_type(nil)).to be_nil
      expect(commit.uri_type("")).to be_nil
    end
  end

  describe '#uri_type with Gitaly enabled' do
    it_behaves_like "#uri_type"
  end

  describe '#uri_type with Rugged enabled', :enable_rugged do
    it 'calls out to the Rugged implementation' do
      allow_any_instance_of(Rugged::Tree).to receive(:path).with('files/html').and_call_original

      commit.uri_type('files/html')
    end

    it_behaves_like '#uri_type'
  end

  describe '.from_hash' do
    subject { described_class.from_hash(commit.to_hash, container) }

    shared_examples 'returns Commit' do
      it 'returns a Commit' do
        expect(subject).to be_an_instance_of(described_class)
      end

      it 'wraps a Gitlab::Git::Commit' do
        expect(subject.raw).to be_an_instance_of(Gitlab::Git::Commit)
      end

      it 'stores the correct commit fields' do
        expect(subject.id).to eq(commit.id)
        expect(subject.message).to eq(commit.message)
      end
    end

    context 'with project' do
      let(:container) { project }

      it_behaves_like 'returns Commit'
    end

    context 'with personal snippet' do
      let(:container) { personal_snippet }

      it_behaves_like 'returns Commit'
    end

    context 'with project snippet' do
      let(:container) { project_snippet }

      it_behaves_like 'returns Commit'
    end
  end

  describe '#work_in_progress?' do
    [
      'squash! ', 'fixup! ', 'wip: ', 'WIP: ', '[WIP] ',
      'draft: ', 'Draft - ', '[Draft] ', '(draft) ', 'Draft: '
    ].each do |wip_prefix|
      it "detects the '#{wip_prefix}' prefix" do
        commit.message = "#{wip_prefix}#{commit.message}"

        expect(commit).to be_work_in_progress
      end
    end

    it "detects WIP for a commit just saying 'wip'" do
      commit.message = "wip"

      expect(commit).to be_work_in_progress
    end

    it "detects WIP for a commit just saying 'draft'" do
      commit.message = "draft"

      expect(commit).to be_work_in_progress
    end

    it "doesn't detect WIP for a commit that begins with 'FIXUP! '" do
      commit.message = "FIXUP! #{commit.message}"

      expect(commit).not_to be_work_in_progress
    end

    it "doesn't detect WIP for words starting with WIP" do
      commit.message = "Wipout #{commit.message}"

      expect(commit).not_to be_work_in_progress
    end
  end

  describe '.valid_hash?' do
    it 'checks hash contents' do
      expect(described_class.valid_hash?('abcdef01239ABCDEF')).to be true
      expect(described_class.valid_hash?("abcdef01239ABCD\nEF")).to be false
      expect(described_class.valid_hash?(' abcdef01239ABCDEF ')).to be false
      expect(described_class.valid_hash?('Gabcdef01239ABCDEF')).to be false
      expect(described_class.valid_hash?('gabcdef01239ABCDEF')).to be false
      expect(described_class.valid_hash?('-abcdef01239ABCDEF')).to be false
    end

    it 'checks hash length' do
      expect(described_class.valid_hash?('a' * 6)).to be false
      expect(described_class.valid_hash?('a' * 7)).to be true
      expect(described_class.valid_hash?('a' * 40)).to be true
      expect(described_class.valid_hash?('a' * 41)).to be false
    end
  end

  describe 'signed commits' do
    let(:gpg_signed_commit) { project.commit_by(oid: '0b4bc9a49b562e85de7cc9e834518ea6828729b9') }
    let(:x509_signed_commit) { project.commit_by(oid: '189a6c924013fc3fe40d6f1ec1dc20214183bc97') }
    let(:unsigned_commit) { project.commit_by(oid: '54fcc214b94e78d7a41a9a8fe6d87a5e59500e51') }
    let!(:commit) { create(:commit, project: project) }

    it 'returns signature_type properly' do
      expect(gpg_signed_commit.signature_type).to eq(:PGP)
      expect(x509_signed_commit.signature_type).to eq(:X509)
      expect(unsigned_commit.signature_type).to eq(:NONE)
      expect(commit.signature_type).to eq(:NONE)
    end

    it 'returns has_signature? properly' do
      expect(gpg_signed_commit.has_signature?).to be_truthy
      expect(x509_signed_commit.has_signature?).to be_truthy
      expect(unsigned_commit.has_signature?).to be_falsey
      expect(commit.has_signature?).to be_falsey
    end
  end

  describe '#reverting_commit' do
    let(:user) { create(:user) }
    let(:issue) { create(:issue, author: user, project: project) }

    it 'returns the reverting commit' do
      create(:note_on_issue,
             noteable: issue,
             system: true,
             note: commit.revert_description(user),
             project: issue.project)

      expect_next_instance_of(Commit) do |revert_commit|
        expect(revert_commit).to receive(:reverts_commit?)
          .with(commit, user)
          .and_return(true)
      end

      expect(commit.reverting_commit(user, issue.notes_with_associations)).to eq(commit)
    end
  end

  describe '#has_been_reverted?' do
    let(:user) { create(:user) }
    let(:issue) { create(:issue, author: user, project: project) }

    it 'returns true if the commit has been reverted' do
      create(:note_on_issue,
             noteable: issue,
             system: true,
             note: commit.revert_description(user),
             project: issue.project)

      expect_next_instance_of(Commit) do |revert_commit|
        expect(revert_commit).to receive(:reverts_commit?)
          .with(commit, user)
          .and_return(true)
      end

      expect(commit.has_been_reverted?(user, issue.notes_with_associations)).to eq(true)
    end

    it 'returns false if the commit has not been reverted' do
      expect(commit.has_been_reverted?(user, issue.notes_with_associations)).to eq(false)
    end
  end
end
